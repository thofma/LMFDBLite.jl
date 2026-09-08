function test_ordering_database(options)
    admin = LMFDBLite.LMFDBConnection(; options...)
    try
        close(DBInterface.execute(admin.conn.raw, """
            CREATE SCHEMA ordering;
            CREATE TABLE ordering.nf_fields (
                id bigint PRIMARY KEY, label text, degree smallint, class_number numeric,
                disc_abs numeric, disc_sign smallint, regulator numeric, cm boolean);
            INSERT INTO ordering.nf_fields VALUES
                (8, 'b', 2, 1, 3, -1, NULL, true),
                (3, 'z', 3, 2, 100, -1, 0.5, false),
                (6, 'a', 2, 1, 5, 1, 1.5, false),
                (1, 'c', 2, 2, 10, -1, NULL, true),
                (9, 'd', NULL, NULL, NULL, NULL, NULL, NULL),
                (4, 'e', 3, 2, 1, 1, 0.25, true);
            CREATE TABLE ordering.ec_curvedata (
                id bigint PRIMARY KEY, lmfdb_label text, conductor integer,
                rank smallint, "absD" numeric, "signD" smallint, torsion smallint);
            INSERT INTO ordering.ec_curvedata VALUES
                (3, 'q-c', 37, 1, 37, 1, 1),
                (2, 'q-b', 11, 0, 161051, -1, 5),
                (1, 'q-a', 11, NULL, 11, -1, 1);
            CREATE TABLE ordering.ec_nfcurves (
                id bigint PRIMARY KEY, label text, conductor_norm bigint, rank smallint);
            INSERT INTO ordering.ec_nfcurves VALUES
                (3, 'nf-c', 89, 1), (2, 'nf-b', 31, 0), (1, 'nf-a', 31, NULL);
            CREATE TABLE ordering.lat_lattices_new (
                id bigint PRIMARY KEY, label text, disc bigint, rank smallint);
            INSERT INTO ordering.lat_lattices_new VALUES (2, 'l-b', 9, 3), (1, 'l-a', -1, 3);
            CREATE TABLE ordering.lat_genera (
                id bigint PRIMARY KEY, label text, det bigint, rank smallint);
            INSERT INTO ordering.lat_genera VALUES (2, 'g-b', 9, 3), (1, 'g-a', -1, 3);
            """))
    finally
        DBInterface.close!(admin)
    end
    conn = LMFDBLite.LMFDBConnection(; options..., schema = "ordering")
    try
        @testset "Ordering before limits in a temporary database" begin
            ids(rows) = getproperty.(rows, :id)
            query(; kw...) = LMFDBLite.search(conn, "nf_fields"; kw...)
            @test ids(query(order_by = :degree)) == [1, 6, 8, 3, 4, 9]
            @test ids(query(order_by = :degree => :desc)) == [3, 4, 1, 6, 8, 9]
            @test ids(query(order_by = (:degree, :class_number => :desc))) == [1, 6, 8, 3, 4, 9]
            @test ids(query(order_by = (:degree => :desc, :class_number))) == [3, 4, 6, 8, 1, 9]
            @test ids(query(order_by = (:degree, :label => :desc))) == [1, 8, 6, 3, 4, 9]
            @test ids(query(order_by = :degree, limit = 2)) == [1, 6]
            @test ids(query(order_by = :degree, limit = 4)) == [1, 6, 8, 3]
            @test ids(query(degree = 2, order_by = :label, limit = 2)) == [6, 8]
            @test isempty(query(order_by = :degree, limit = 0))
            @test ids(query(order_by = :discriminant)) == [3, 1, 8, 4, 6, 9]
            @test ids(query(order_by = :discriminant => :desc)) == [6, 4, 8, 1, 3, 9]
            @test ids(query(order_by = :regulator)) == [4, 3, 6, 1, 8, 9]
            @test ids(query(order_by = :regulator => :desc)) == [6, 3, 4, 1, 8, 9]
            @test ids(query(order_by = :is_cm)) == [3, 6, 1, 4, 8, 9]
            # Change physical row placement: requested order must still win.
            close(DBInterface.execute(conn.conn.raw, "UPDATE ordering.nf_fields SET degree = degree WHERE id = 1"))
            @test ids(query(order_by = :degree, limit = 2)) == [1, 6]

            for (table, order, expected, count_function) in
                    (("ec_curvedata", (:conductor, :rank => :desc), [2, 1, 3], LMFDBLite.count_elliptic_curves),
                     ("ec_nfcurves", (:conductor_norm, :rank => :desc), [2, 1, 3], LMFDBLite.count_elliptic_curves_over_number_fields),
                     ("lat_lattices_new", :disc, [1, 2], LMFDBLite.count_integer_lattices),
                     ("lat_genera", :det => :desc, [2, 1], LMFDBLite.count_genera),
                     ("nf_fields", :discriminant, [3, 1, 8, 4, 6, 9], LMFDBLite.count_number_fields))
                @test ids(LMFDBLite.search(conn, table; order_by = order)) == expected
                @test count_function(conn; order_by = order, limit = 1) == 1
                @test count_function(conn; order_by = order) == length(expected)
                @test count_function(conn; order_by = order, limit = 0) == 0
            end
            @test ids(LMFDBLite.search(conn, "ec_curvedata"; order_by = :label)) == [1, 2, 3]
            @test ids(LMFDBLite.search(conn, "ec_curvedata"; order_by = :discriminant)) == [2, 1, 3]
            @test ids(LMFDBLite.search(conn, "ec_curvedata"; order_by = :torsion_order => :desc)) == [2, 1, 3]
            @test_throws ArgumentError query(order_by = (:degree, :degree => :desc))
            @test_throws ArgumentError query(apply_order = false)
            @test_throws ArgumentError LMFDBLite.count(conn, "nf_fields"; order_by = :bad)
            @test_throws ArgumentError LMFDBLite.count(conn, "nf_fields"; order_by = :signature)

            # Check the shared query builder, including the mode used by count.
            for order_by in (nothing, (), [])
                sql = string(LMFDBLite.FunSQL.render(conn.conn,
                    LMFDBLite._search_query(conn, "nf_fields"; order_by, limit = 2)))
                @test !occursin("ORDER BY", sql)
            end
            for (apply_order, expected) in ((true, true), (false, false))
                sql = string(LMFDBLite.FunSQL.render(conn.conn,
                    LMFDBLite._search_query(conn, "nf_fields", apply_order; order_by = :degree, limit = 2)))
                @test occursin("ORDER BY", sql) == expected
                @test occursin("LIMIT", sql)
            end
        end
    finally
        DBInterface.close!(conn)
    end
end
