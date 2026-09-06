function test_elliptic_curves(conn::LMFDBLite.LMFDBConnection)
    @testset "Elliptic curves over Q" begin
        table = "ec_curvedata"
        @test isnothing(LMFDBLite.check_search_parameters(conn, table))
        layout = LMFDBLite.table_layout(conn, table)
        @testset "$parameter" for (parameter, spec) in LMFDBLite._elliptic_curve_parameters()
            @test isnothing(LMFDBLite._check_parameter_schema(layout, table, parameter, spec))
        end

        reference = LMFDBLite.search(conn, table; conductor = 11)
        @test Set(r.lmfdb_label for r in reference) == Set(["11.a1", "11.a2", "11.a3"])
        @test LMFDBLite.count(conn, table; conductor = 11) == 3
        @test LMFDBLite.count_elliptic_curves(conn; conductor = 11) == 3

        labels(rows) = Set(r.lmfdb_label for r in rows)
        @test labels(LMFDBLite.search(conn, table; isogeny_class = "11.a")) == labels(reference)
        @test labels(LMFDBLite.search(conn, table; label = in(["11.a1", "11.a3"]))) == Set(["11.a1", "11.a3"])
        @test labels(LMFDBLite.search(conn, table; conductor = in(11:11), rank = 0,
                                     analytic_rank = 0, semistable = true)) == labels(reference)
        @test labels(LMFDBLite.search(conn, table; conductor = 11,
                                     torsion_structure = [5])) == Set(["11.a2", "11.a3"])

        sample = only(filter(r -> r.lmfdb_label == "11.a2", reference))
        ainvs = BigInt.(sample.ainvs)
        discriminant = BigInt(sample.signD) * BigInt(sample.absD)
        @test labels(LMFDBLite.search(conn, table; a_invariants = ainvs)) == Set([sample.lmfdb_label])
        @test labels(LMFDBLite.search(conn, table; discriminant)) == Set([sample.lmfdb_label])
        @test_throws ArgumentError LMFDBLite.search(conn, table; genus_label = "x", limit = 1)

        E = LMFDBLite.elliptic_curve(conn, sample.lmfdb_label)
        @test collect(Hecke.a_invariants(E)) == Hecke.QQ.(ainvs)
        @test Hecke.get_attribute(E, :lmfdb_label) == sample.lmfdb_label
        curves = LMFDBLite.elliptic_curves(conn; conductor = 11, torsion_structure = [5])
        @test length(curves) == 2
        @test Set(Hecke.get_attribute(C, :lmfdb_label) for C in curves) == Set(["11.a2", "11.a3"])
        @test isempty(LMFDBLite.elliptic_curves(conn; conductor = 11, limit = 0))
        @test_throws ErrorException LMFDBLite.elliptic_curve(conn, "not-an-elliptic-curve-label")
    end
end
