function test_number_field_curve_database(options)
    admin = LMFDBLite.LMFDBConnection(; options...)
    try
        close(DBInterface.execute(admin.conn.raw, """
            CREATE TABLE public.ec_nfcurves (
                label text, field_label text, degree smallint, signature jsonb,
                conductor_norm bigint, conductor_label text, class_label text,
                torsion_structure jsonb, torsion_primes integer[], rank smallint,
                ainvs text, jinv text);
            INSERT INTO public.ec_nfcurves VALUES
                ('2.2.5.1-31.1-a1', '2.2.5.1', 2, '[2,0]', 31, '31.1', '2.2.5.1-31.1-a',
                 '[8]', '{2}', 0, '1,0;1,1;0,1;0,1;0,0', '51455/31,-106208/31'),
                ('3.1.23.1-89.1-A1', '3.1.23.1', 3, '[1,1]', 89, '89.1', '3.1.23.1-89.1-A',
                 '[10]', '{2,5}', 0, '1,1,0;-1,-1,-1;0,1,1;0,0,-1;1,0,-1', '275391/89,-337201/89,197037/89'),
                ('unknown-rank', '2.2.5.1', 2, '[2,0]', 100, '100.1', 'unknown',
                 '[]', '{}', NULL, '0;0;0;-1;0', '1728');
            CREATE TABLE public.ec_curvedata (lmfdb_label text, conductor integer);
            INSERT INTO public.ec_curvedata VALUES ('11.a1', 11);
            """))
    finally
        DBInterface.close!(admin)
    end
    conn = LMFDBLite.LMFDBConnection(; options...)
    try
        @testset "Number field curve queries in a temporary database" begin
            # The count API works in the core, before the Hecke extension loads.
            @test Base.get_extension(LMFDBLite, :LMFDBLiteHeckeExt) === nothing
            @test LMFDBLite.count_elliptic_curves_over_number_fields(conn) == 3
            @test LMFDBLite.count_elliptic_curves_over_number_fields(conn; field_label = "2.2.5.1") == 2
            @test LMFDBLite.count_elliptic_curves_over_number_fields(conn; rank = 0) == 2
            @test LMFDBLite.count_elliptic_curves_over_number_fields(conn; limit = 1) == 1
            @test LMFDBLite.count_elliptic_curves_over_number_fields(conn; limit = 0) == 0
            @test LMFDBLite.count_elliptic_curves(conn; conductor = 11) == 1
            table = "ec_nfcurves"
            rows = LMFDBLite.search(conn, table; signature = (2, 0), torsion_structure = [8],
                                   conductor_norm = in(1:50), torsion_primes = [2])
            @test getproperty.(rows, :label) == ["2.2.5.1-31.1-a1"]
            @test LMFDBLite.count(conn, table; signature = anyof((2, 0), (1, 1))) == 3
            @test LMFDBLite.count(conn, table; signature = allof((2, 0), (1, 1))) == 0
            @test LMFDBLite.count(conn, table; torsion_structure = Int[]) == 1
            @test LMFDBLite.count(conn, table; field_label = in(String[])) == 0
            sample = only(rows)
            @test only(LMFDBLite.search(conn, table; ainvs = sample.ainvs)).label == sample.label
            @test only(LMFDBLite.search(conn, table; jinv = sample.jinv)).label == sample.label
            @test_throws ArgumentError LMFDBLite.search(conn, table; conductor = 31)
        end
    finally
        DBInterface.close!(conn)
    end
end
