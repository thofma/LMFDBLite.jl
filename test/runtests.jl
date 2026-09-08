using LMFDBLite
using DBInterface
using Test

@testset "LMFDBLite without Hecke" begin
    @test Base.PkgId(LMFDBLite).name == "LMFDBLite"
    @test parentmodule(LMFDBLite.LMFDBConnection) === LMFDBLite
    @test Base.get_extension(LMFDBLite, :LMFDBLiteHeckeExt) === nothing
    @test !isdefined(LMFDBLite, :Hecke)
    @test !isdefined(LMFDBLite, :number_field)
    @test !isdefined(LMFDBLite, :elliptic_curve)
    @test !isdefined(LMFDBLite, :genus)
    @test lmfdb === LMFDBLite.lmfdb
    @test includes === LMFDBLite.includes
    @test allof === LMFDBLite.allof
    @test anyof === LMFDBLite.anyof
    @test Set(names(LMFDBLite)) == Set((:LMFDBLite, :includes, :lmfdb, :reset!, :allof, :anyof))
    @test reset! === LMFDBLite.reset!
    @test hasmethod(reset!, Tuple{LMFDBLite.LMFDBConnection})
    @test isempty(methods(LMFDBLite.number_fields))
    @test isempty(methods(LMFDBLite.elliptic_curves))
    @test haskey(LMFDBLite._number_field_parameter_definitions(), :galois_group)
    @test haskey(LMFDBLite._elliptic_curve_parameter_definitions(), :conductor)
    @test hasmethod(LMFDBLite.count_number_fields, Tuple{LMFDBLite.LMFDBConnection})
    @test hasmethod(LMFDBLite.count_elliptic_curves, Tuple{LMFDBLite.LMFDBConnection})
    @test hasmethod(LMFDBLite.count_integer_lattices, Tuple{LMFDBLite.LMFDBConnection})
    @test hasmethod(LMFDBLite.count_genera, Tuple{LMFDBLite.LMFDBConnection})
end

include("parameter_consistency.jl")
include("metadata.jl")
if haskey(ENV, "LMFDB_POSTGRES_BIN")
    include("metadata_postgresql.jl")
end
include("discriminants.jl")
include("number_field_conditions.jl")
include("composition.jl")
include("integer_ranges.jl")

using Hecke

@testset "Hecke extension" begin
    @test Base.get_extension(LMFDBLite, :LMFDBLiteHeckeExt) !== nothing
    @test !isdefined(LMFDBLite, :number_field)
    @test !isdefined(LMFDBLite, :elliptic_curve)
    @test !isdefined(LMFDBLite, :genus)
    @test hasmethod(Hecke.number_field, Tuple{LMFDBLite.LMFDBConnection, String})
    @test hasmethod(Hecke.elliptic_curve, Tuple{LMFDBLite.LMFDBConnection, String})
    @test hasmethod(Hecke.genus, Tuple{LMFDBLite.LMFDBConnection, String})
    @test hasmethod(LMFDBLite.number_fields, Tuple{LMFDBLite.LMFDBConnection})
    @test hasmethod(LMFDBLite.integer_lattice, Tuple{LMFDBLite.LMFDBConnection, String})
end

# ZZRingElem is also Oscar's integer type; these tests need no database.
test_discriminant_inputs(Hecke.ZZ)
test_discriminant_ranges(Hecke.ZZ)
test_number_field_conditions(Hecke.ZZ)
test_number_field_integer_ranges(Hecke.ZZ)
test_large_number_field_conditions(Hecke.ZZ)
test_composition_inputs(Hecke.ZZ)
test_integer_ranges(Hecke.ZZ)
test_large_integer_ranges(Hecke.ZZ, big(10)^30)

@testset "ZZRingElem discriminants beyond machine integers" begin
    value = big(2)^128 + 1
    for table in ("nf_fields", "ec_curvedata"), criterion in
            (identity, ==, <, <=, >, >=, x -> in([-x, x]), x -> in(-x:x))
        condition = discriminant_condition(table, criterion(Hecke.ZZ(value)))
        expected = discriminant_condition(table, criterion(value))
        sql = discriminant_sql(table, condition)
        @test sql == discriminant_sql(table, expected)
        @test sizeof(sql) < 700
    end
end

# Use the package's default public database, with optional connection overrides.
connection_options = Dict{Symbol, String}()
for key in (:host, :port, :dbname, :user, :password, :schema)
    env_key = "LMFDB_" * uppercase(string(key))
    if haskey(ENV, env_key)
        connection_options[key] = ENV[env_key]
    end
end

@testset "LMFDB live database tests" begin
    conn = LMFDBLite.LMFDBConnection(; connection_options...)
    try
        test_lazy_metadata(conn)
        @test reset!(conn) === nothing
        @test isopen(conn)
        @test sprint(show, conn) ==
            "LMFDB database connection to $(conn.env.host):$(conn.env.port)"
        @test sprint(show, MIME"text/plain"(), conn) ==
            "Connection to the LMFDB database\n" *
            "  host: $(conn.env.host)\n" *
            "  port: $(conn.env.port)"
        @testset "Cached default connection" begin
            cached = LMFDBLite.lmfdb()
            @test cached isa LMFDBLite.LMFDBConnection
            @test isopen(cached)
            @test LMFDBLite.lmfdb() === cached
            @test all(fetch(task) === cached for task in
                [Threads.@spawn LMFDBLite.lmfdb() for _ in 1:4])
            @test conn !== cached
            DBInterface.close!(cached)
            @test !isopen(cached)
            replacement = LMFDBLite.lmfdb()
            @test replacement !== cached
            @test isopen(replacement)
            DBInterface.close!(replacement)
        end
        test_number_field_parameter_consistency(conn)
        include("number_fields.jl")
        test_number_fields(conn)
        include("lattices.jl")
        test_lattices_and_genera(conn)
        include("elliptic_curves.jl")
        test_elliptic_curves(conn)
    finally
        DBInterface.close!(conn)
    end
end
