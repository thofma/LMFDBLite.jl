function test_elliptic_curves_over_number_fields(conn::LMFDBLite.LMFDBConnection)
    @testset "Elliptic curves over number fields" begin
        table = "ec_nfcurves"
        @test isnothing(LMFDBLite.check_search_parameters(conn, table))
        reference_labels = ["2.2.5.1-31.1-a1", "2.2.5.1-599.1-b1", "3.1.23.1-89.1-A1"]
        reference = LMFDBLite.search(conn, table; label = in(reference_labels))
        labels(rows) = Set(r.label for r in rows)
        # LibPQ returns JSONB columns as text; SQL still compares JSON values.
        json_text(value) = replace(value, r"\s+" => "")
        @test labels(reference) == Set(reference_labels)
        bounds = (; label = in(reference_labels))
        @test LMFDBLite.count_elliptic_curves_over_number_fields(conn; bounds...) == 3
        @test LMFDBLite.count_elliptic_curves_over_number_fields(conn; bounds..., limit = 2) == 2
        @test LMFDBLite.count_elliptic_curves_over_number_fields(conn; bounds..., limit = 0) == 0
        for (parameter, criterion, predicate) in
                ((:field_label, "2.2.5.1", r -> r.field_label == "2.2.5.1"),
                 (:conductor_norm, allof(>=(31), <=(89)), r -> 31 <= r.conductor_norm <= 89),
                 (:signature, anyof((2, 0), (1, 1)), r -> json_text(r.signature) in ("[2,0]", "[1,1]")),
                 (:torsion_structure, [8], r -> json_text(r.torsion_structure) == "[8]"),
                 (:isogeny_class, "3.1.23.1-89.1-A", r -> r.class_label == "3.1.23.1-89.1-A"))
            rows = LMFDBLite.search(conn, table; bounds..., parameter => criterion)
            @test labels(rows) == labels(filter(predicate, reference))
        end
        for sample in reference, (parameter, column) in
                ((:a_invariants, :ainvs), (:j_invariant, :jinv), (:torsion_primes, :torsion_primes),
                 (:isogeny_degrees, :isodeg), (:semistable, :semistable), (:is_q_curve, :q_curve))
            value = getproperty(sample, column)
            ismissing(value) && continue
            @test !isempty(LMFDBLite.search(conn, table; label = sample.label, parameter => value))
        end
        @test_throws ArgumentError LMFDBLite.search(conn, table; conductor = 31, limit = 1)
        @test_throws ArgumentError LMFDBLite.search(conn, table; signature = (0, 0), limit = 1)

        curves = LMFDBLite.elliptic_curves_over_number_fields(conn; bounds...)
        @test Set(get_attribute.(curves, :lmfdb_label)) == Set(reference_labels)
        quadratic_curves = filter(E -> get_attribute(base_field(E), :lmfdb_label) == "2.2.5.1", curves)
        @test length(quadratic_curves) == 2
        @test base_field(quadratic_curves[1]) === base_field(quadratic_curves[2])
        for curve in curves
            label = get_attribute(curve, :lmfdb_label)
            separate = Hecke.elliptic_curve(conn, label)
            @test get_attribute(separate, :lmfdb_label) == label
            @test defining_polynomial(base_field(separate)) == defining_polynomial(base_field(curve))
            # Compare coefficients, since separate calls intentionally use separate parents.
            @test [collect(coefficients(x)) for x in a_invariants(separate)] ==
                  [collect(coefficients(x)) for x in a_invariants(curve)]
        end
        @test isempty(LMFDBLite.elliptic_curves_over_number_fields(conn; bounds..., limit = 0))
        @test length(LMFDBLite.elliptic_curves_over_number_fields(conn; bounds..., limit = 1)) == 1
        @test isempty(LMFDBLite.elliptic_curves_over_number_fields(conn; field_label = "nonexistent"))
        @test_throws ErrorException Hecke.elliptic_curve(conn, "2.2.5.1-0.0-z0")
    end
end
