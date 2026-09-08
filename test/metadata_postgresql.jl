# This standalone test creates and stops its own private PostgreSQL cluster.
# It never uses the public mirror or LMFDB_* connection credentials.
using LMFDBLite
using DBInterface
using Test
import LibPQ

include("elliptic_curve_number_field_database.jl")

function test_metadata_database(options)
    raw = DBInterface.connect(LibPQ.Connection,
        "host=$(options.host) port=$(options.port) dbname=postgres user=lmfdblite_test")
    try
        # The conflicting schema comes first in search_path for every subsequent
        # connection. Its type and rows differ from the public table deliberately.
        close(DBInterface.execute(raw, """
            CREATE SCHEMA other;
            CREATE TABLE public.nf_fields (
                label text, degree smallint, r2 smallint,
                disc_abs numeric(30, 0), disc_sign smallint);
            INSERT INTO public.nf_fields VALUES ('public-field', 2, 0, 5, 1);
            CREATE TABLE other.nf_fields (label text, degree text, extra integer);
            INSERT INTO other.nf_fields VALUES ('other-field', 'two', 99);
            CREATE TABLE public.unrelated (d date, u uuid, t timestamp with time zone);
            CREATE TABLE other.other_only (d date);
            CREATE TABLE public.mapping_types (c character(3), o oidvector, i int2vector);
            CREATE VIEW public.field_view AS SELECT label, degree FROM public.nf_fields;
            ALTER DATABASE postgres SET search_path TO other, public;
            """))
    finally
        DBInterface.close!(raw)
    end

    conn = LMFDBLite.LMFDBConnection(; options...)
    try
        @test conn.schema == "public"
        @test only(ci.val for ci in LibPQ.conninfo(conn.conn.raw.conn) if ci.keyword == "sslmode") == "disable"
        @test isempty(conn.table_layouts)
        @test Set(conn.table_names) == Set(["nf_fields", "unrelated", "mapping_types", "field_view"])
        @test length(conn.table_names) == length(unique(conn.table_names))
        @test all(table.qualifiers == [:public] for table in values(conn.conn.catalog))

        # Concurrent first requests must share one successfully cached layout.
        tasks = [Threads.@spawn LMFDBLite.table_layout(conn, "nf_fields") for _ in 1:4]
        layouts = fetch.(tasks)
        @test all(layout -> layout === first(layouts), layouts)
        layout = first(layouts)
        SQL = LMFDBLite.SQL
        @test layout[SQL.FieldName(:degree)] isa SQL.smallint
        @test layout[SQL.FieldName(:disc_abs)] isa SQL.numeric
        @test !haskey(layout, SQL.FieldName(:extra))
        @test Set(keys(conn.table_layouts)) == Set([("public", "nf_fields")])

        records = LMFDBLite.search(conn, "nf_fields"; degree = 2, signature = (2, 0), discriminant = 5)
        @test getproperty.(records, :label) == ["public-field"]
        @test LMFDBLite.count(conn, "nf_fields"; degree = 2) == 1
        @test_throws r"requires missing column `nf_fields.class_number`" LMFDBLite.search(
            conn, "nf_fields"; class_number = 1)
        @test_throws ArgumentError LMFDBLite.check_table_name(conn, "other_only")

        # Reject unsupported searches before trying to interpret their columns.
        @test_throws ArgumentError LMFDBLite.search(conn, "unrelated")
        @test_throws ArgumentError LMFDBLite.check_search_parameters(conn, "unrelated")
        @test !haskey(conn.table_layouts, ("public", "unrelated"))
        @test_throws r"Type of name \"date\" not added yet" LMFDBLite.table_layout(conn, "unrelated")
        @test !haskey(conn.table_layouts, ("public", "unrelated"))
        @test LMFDBLite.count(conn, "nf_fields"; degree = 2) == 1

        mapping = LMFDBLite.table_layout(conn, "mapping_types")
        @test mapping[SQL.FieldName(:c)] isa SQL.character
        @test mapping[SQL.FieldName(:o)] isa SQL.oidvector
        @test mapping[SQL.FieldName(:i)] isa SQL.int2vector
        @test LMFDBLite.table_layout(conn, "field_view")[SQL.FieldName(:degree)] isa SQL.smallint

        # A cached layout stays usable without another metadata query.
        DBInterface.close!(conn)
        @test LMFDBLite.table_layout(conn, "nf_fields") === layout
    finally
        DBInterface.close!(conn)
    end

    other = LMFDBLite.LMFDBConnection(; options..., schema = "other")
    try
        @test Set(other.table_names) == Set(["nf_fields", "other_only"])
        @test isempty(other.table_layouts)
        @test getproperty.(LMFDBLite.search(other, "nf_fields"), :label) == ["other-field"]
        @test Set(keys(other.table_layouts)) == Set([("other", "nf_fields")])
        @test_throws r"column `nf_fields.degree` has type .*text; expected .*smallint" LMFDBLite.search(
            other, "nf_fields"; degree = 2)
    finally
        DBInterface.close!(other)
    end

    # Schema values are bound parameters for metadata and quoted identifiers in
    # generated searches, including names that cannot be used unquoted in SQL.
    special_schema = "odd ' schema"
    admin = LMFDBLite.LMFDBConnection(; options...)
    try
        close(DBInterface.execute(admin.conn.raw, """
            CREATE SCHEMA "odd ' schema";
            CREATE TABLE "odd ' schema".nf_fields (label text, degree smallint);
            INSERT INTO "odd ' schema".nf_fields VALUES ('quoted-schema', 3);
            """))
    finally
        DBInterface.close!(admin)
    end
    special = LMFDBLite.LMFDBConnection(; options..., schema = special_schema)
    try
        @test special.table_names == ["nf_fields"]
        @test getproperty.(LMFDBLite.search(special, "nf_fields"; degree = 3), :label) == ["quoted-schema"]
        @test Set(keys(special.table_layouts)) == Set([(special_schema, "nf_fields")])
    finally
        DBInterface.close!(special)
    end
end

@testset "Metadata isolation in a temporary PostgreSQL database" begin
    pg_bin = ENV["LMFDB_POSTGRES_BIN"]
    mktempdir("/tmp"; prefix = "lmfdblite-pg-") do root
        data = joinpath(root, "data")
        log = joinpath(root, "postgres.log")
        initdb = joinpath(pg_bin, "initdb")
        pg_ctl = joinpath(pg_bin, "pg_ctl")
        run(pipeline(`$initdb -D $data --auth=trust --no-locale --encoding=UTF8 --username=lmfdblite_test`;
                     stdout = devnull))
        try
            # No TCP listener; the socket is inside this private temporary directory.
            run(pipeline(`$pg_ctl -D $data -l $log -o $("-F -k $root -h '' -p 65432") -w -t 30 start`;
                         stdout = devnull))
            options = (; host = root, port = "65432", dbname = "postgres",
                       user = "lmfdblite_test", password = "",
                       connect_timeout = 5, sslmode = "disable")
            test_metadata_database(options)
            test_number_field_curve_database(options)
        catch
            isfile(log) && print(stderr, read(log, String))
            rethrow()
        finally
            if isfile(joinpath(data, "postmaster.pid"))
                run(pipeline(`$pg_ctl -D $data -m immediate -w -t 30 stop`; stdout = devnull))
            end
        end
    end
end
