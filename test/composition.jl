import FunSQL

function composition_condition(table, parameter, value)
    spec = LMFDBLite._search_parameter_definitions(table)[parameter]
    _, _, column, builder, allowed = spec
    condition = builder(column, value, parameter, allowed)
    columns, _ = LMFDBLite._parameter_columns_and_types(spec)
    LMFDBLite._assert_parameter_columns(condition, columns, parameter)
    return condition
end

function test_live_signature_composition(conn, table, reference)
    @testset "Signature composition against live records: $table" begin
        labels(rows) = Set(r.label for r in rows)
        if table == "nf_fields"
            a, b, c = (1, 0), (0, 1), (2, 0)
            signature = r -> (r.degree - 2r.r2, r.r2)
        else
            a, b, c = (1, 0), (0, 1), (1, 1)
            signature = r -> (r.nplus, r.rank - r.nplus)
        end
        cases = [
            (anyof(a, b), s -> s in (a, b)),
            (anyof(==(a), ==(b), ==(c)), s -> s in (a, b, c)),
            (allof(anyof(a, b), anyof(b, c), ==(b)), s -> s == b),
            (anyof(allof(a, ==(a)), allof(c, ==(c))), s -> s in (a, c)),
            (allof(a, b), s -> false),
        ]
        for (criterion, predicate) in cases
            rows = LMFDBLite.search(conn, table;
                label = in([r.label for r in reference]), signature = criterion)
            @test labels(rows) == labels(filter(r -> predicate(signature(r)), reference))
        end
        @test_throws ArgumentError LMFDBLite.search(conn, table;
            signature = anyof(a, allof(b, <(c))))
    end
end

function composition_sql(table, parameter, condition)
    spec = LMFDBLite._search_parameter_definitions(table)[parameter]
    columns, _ = LMFDBLite._parameter_columns_and_types(spec)
    query = FunSQL.From(FunSQL.SQLTable(Symbol(table); columns = collect(columns))) |>
            LMFDBLite._create_where([condition])
    return string(FunSQL.render(query; dialect = :postgresql))
end

function test_composition_inputs(convert_value)
    @testset "Public composition: $(typeof(convert_value(0)))" begin
        reference = BigInt[-2, 0, 1, 2, 3, 4, 5, 6, 8]
        a, b, c = convert_value.((2, 4, 6))
        cases = [
            (anyof(==(a), ==(b)), x -> x in (2, 4)),
            (allof(>=(a), <=(c), in(convert_value.([1, 2, 4, 8]))), x -> x in (2, 4)),
            (anyof(a, b, c), x -> x in (2, 4, 6)),
            (allof(>=(b), anyof(==(a), ==(c))), x -> x == 6),
            (anyof(allof(>=(a), <=(b)), allof(>(b), <(c))), x -> 2 <= x < 6),
            (allof(anyof(==(a), ==(b)), anyof(==(b), ==(c))), x -> x == 4),
            (anyof(allof(==(a), ==(b)), allof(==(b), ==(c))), x -> false),
        ]
        for (table, parameter, column) in
                (("nf_fields", :class_number, :class_number),
                 ("nf_fields", :degree, :degree),
                 ("ec_curvedata", :conductor, :conductor),
                 ("ec_nfcurves", :conductor_norm, :conductor_norm),
                 ("lat_lattices_new", :rank, :rank), ("lat_genera", :rank, :rank))
            for (criterion, predicate) in cases
                condition = composition_condition(table, parameter, criterion)
                actual = filter(reference) do value
                    row = NamedTuple{(column,)}((value,))
                    evaluate_number_field_condition(condition, row)
                end
                @test actual == filter(predicate, reference)
                @test occursin("WHERE", composition_sql(table, parameter, condition))
            end
        end
    end
end

function test_signature_composition(T)
    @testset "Signature composition: $T" begin
        a, b, c = T.((2, 0)), T.((1, 2)), T.((0, 3))
        cases = [
            (a, s -> s == (2, 0)),
            (==(collect(b)), s -> s == (1, 2)),
            (anyof(a, ==(b), collect(c)), s -> s in ((2, 0), (1, 2), (0, 3))),
            (allof(anyof(a, b), anyof(b, c), ==(b)), s -> s == (1, 2)),
            (anyof(allof(a, ==(a)), allof(b, ==(b))), s -> s in ((2, 0), (1, 2))),
            (allof(a, b), s -> false),
            (anyof(allof(a, b), c), s -> s == (0, 3)),
        ]
        for table in ("nf_fields", "lat_lattices_new", "lat_genera")
            if table == "nf_fields"
                reference = [(; degree = d, r2) for d in 1:8 for r2 in 0:div(d, 2)]
                signature = r -> (r.degree - 2r.r2, r.r2)
            else
                reference = [(; rank = d, nplus) for d in 1:8 for nplus in 0:d]
                signature = r -> (r.nplus, r.rank - r.nplus)
            end
            # The reference includes valid signatures obtained by mixing the
            # columns of different alternatives. Such rows must not slip through.
            for (criterion, predicate) in cases
                condition = composition_condition(table, :signature, criterion)
                @test filter(r -> evaluate_number_field_condition(condition, r), reference) ==
                      filter(r -> predicate(signature(r)), reference)
                @test occursin("WHERE", composition_sql(table, :signature, condition))
            end
        end
    end
end

@testset "Boolean composition without a database" begin
    @testset "Single and missing arguments" begin
        for value in (==(2), 2, [2, 3], (2, 0), anyof(==(2), ==(3)))
            @test allof(value) === value
            @test anyof(value) === value
        end
        @test_throws ArgumentError allof()
        @test_throws ArgumentError anyof()
    end

    for T in (Int, Int32, BigInt)
        test_composition_inputs(T)
        test_signature_composition(T)
    end

    @testset "Text and boolean equality" begin
        for (parameter, column, criterion, reference, expected) in
                ((:label, :label, allof(anyof("a", "b"), anyof("b", "c")), ["a", "b", "c"], ["b"]),
                 (:is_galois, :is_galois, anyof(false, true), [false, true], [false, true]),
                 (:is_galois, :is_galois, allof(false, true), [false, true], Bool[]))
            condition = composition_condition("nf_fields", parameter, criterion)
            @test filter(x -> evaluate_number_field_condition(condition, NamedTuple{(column,)}((x,))), reference) == expected
            @test occursin("WHERE", composition_sql("nf_fields", parameter, condition))
        end
    end

    @testset "Invalid nested signature conditions" begin
        invalid = ((-1, 1), (0, 0), (2,), [1, 2, 3], (1.5, 1), "2,0",
                   <((2, 0)), in([(2, 0), (0, 1)]), includes([2, 0]))
        for table in ("nf_fields", "lat_lattices_new", "lat_genera"), bad in invalid
            for criterion in (bad, anyof((2, 0), bad),
                              allof(anyof((2, 0), (0, 1)), bad),
                              anyof((2, 0), allof((2, 0), (0, 1), bad)))
                err = try
                    composition_condition(table, :signature, criterion)
                catch e
                    e
                end
                @test err isa ArgumentError
                @test occursin("`signature`", sprint(showerror, err))
            end
        end
    end

    @testset "Invalid nested scalar operators" begin
        for (table, parameter) in (("nf_fields", :class_number), ("ec_curvedata", :conductor),
                                   ("ec_nfcurves", :conductor_norm),
                                   ("lat_lattices_new", :rank), ("lat_genera", :rank))
            for criterion in (allof(in(Int[]), includes([2])),
                              anyof(==(2), allof(>(0), includes([2]))))
                @test_throws ArgumentError composition_condition(table, parameter, criterion)
            end
        end
    end

    @testset "Existing two-predicate conjunction" begin
        legacy = composition_condition("nf_fields", :class_number, >=(2) & <=(5))
        explicit = composition_condition("nf_fields", :class_number, allof(>=(2), <=(5)))
        @test composition_sql("nf_fields", :class_number, legacy) ==
              composition_sql("nf_fields", :class_number, explicit)
    end
end
