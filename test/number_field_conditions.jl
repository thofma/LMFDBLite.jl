import FunSQL

function number_field_condition(parameter, value)
    spec = LMFDBLite._number_field_parameter_definitions()[parameter]
    _, _, column, builder, allowed = spec
    condition = builder(column, value, parameter, allowed)
    columns, _ = LMFDBLite._parameter_columns_and_types(spec)
    LMFDBLite._assert_parameter_columns(condition, columns, parameter)
    return condition
end

function number_field_condition_sql(parameter, condition)
    columns, _ = LMFDBLite._parameter_columns_and_types(LMFDBLite._number_field_parameter_definitions()[parameter])
    query = FunSQL.From(FunSQL.SQLTable(:nf_fields; columns = collect(columns))) |>
            LMFDBLite._create_where([condition])
    return string(FunSQL.render(query; dialect = :postgresql))
end

function evaluate_number_field_condition(c::LMFDBLite.PredC, row)
    operand = c.op.x
    if c.op.f in (issubset, LMFDBLite.issuperset)
        # Decode the numeric SQL array literal to evaluate containment independently.
        operand = parse.(BigInt, split(chop(operand; head = 1, tail = 1), ','; keepempty = false))
    end
    return c.op.f(getproperty(row, c.symb), operand)
end
evaluate_number_field_condition(::LMFDBLite.FalseC, row) = false
evaluate_number_field_condition(c::LMFDBLite.AndC, row) =
    evaluate_number_field_condition(c.a, row) && evaluate_number_field_condition(c.b, row)
evaluate_number_field_condition(c::LMFDBLite.OrC, row) =
    evaluate_number_field_condition(c.a, row) || evaluate_number_field_condition(c.b, row)

function integer_condition_cases(convert_value)
    return [
        (convert_value(2), ==(2)), (==(convert_value(2)), ==(2)),
        (<(convert_value(2)), <(2)), (<=(convert_value(2)), <=(2)),
        (>(convert_value(2)), >(2)), (>=(convert_value(2)), >=(2)),
        (in(convert_value.([0, 2, 3])), d -> d in (0, 2, 3)),
        (in(convert_value.(Int[])), d -> false),
        (allof(>=(convert_value(1)), <=(convert_value(3))), d -> 1 <= d <= 3),
        (allof(>=(convert_value(1)), <=(convert_value(3)), in(convert_value.([1, 3, 5]))), d -> d in (1, 3)),
        (anyof(==(convert_value(0)), >(convert_value(2))), d -> d == 0 || d > 2),
        (allof(anyof(==(convert_value(0)), >(convert_value(2))),
               <(convert_value(4))), d -> (d == 0 || d > 2) && d < 4),
        (anyof(in(convert_value.(Int[])), ==(convert_value(2))), ==(2)),
    ]
end

function ramified_condition_cases(convert_value)
    cases = Any[]
    for values in ([2, 3], [3, 2], [2, 2, 3], Int[])
        expected = Set(values)
        for equality in (identity, ==, v -> Base.Fix2(issetequal, v))
            push!(cases, (equality(convert_value.(values)), x -> Set(x) == expected))
        end
    end
    append!(cases, [
        (LMFDBLite.includes(convert_value.([2, 2])), x -> 2 in x),
        (issubset(convert_value.([2, 3])), x -> all(p -> p in (2, 3), x)),
        (LMFDBLite.includes(convert_value.(Int[])), x -> true),
        (issubset(convert_value.(Int[])), isempty),
        (LMFDBLite.includes(view(convert_value.([2, 3]), 1:1)), x -> 2 in x),
        (allof(LMFDBLite.includes(convert_value.([2])),
               issubset(convert_value.([2, 3, 5])),
               anyof(==(convert_value.([2])), ==(convert_value.([2, 3])))),
         x -> Set(x) == Set([2]) || Set(x) == Set([2, 3])),
        (allof(anyof(==(convert_value.([2])),
                     LMFDBLite.includes(convert_value.([3]))),
               issubset(convert_value.([2, 3]))),
         x -> (Set(x) == Set([2]) || 3 in x) && all(p -> p in (2, 3), x)),
        (anyof(==(convert_value.(Int[])), LMFDBLite.includes(convert_value.([5]))),
         x -> isempty(x) || 5 in x),
    ])
    return cases
end

function test_number_field_conditions(convert_value)
    @testset "Number field conditions: $(typeof(convert_value(0)))" begin
        reference = BigInt[-1, 0, 1, 2, 3, 4, 5]
        for parameter in (:degree, :ramified_prime_count), (criterion, predicate) in integer_condition_cases(convert_value)
            condition = number_field_condition(parameter, criterion)
            actual = filter(d -> evaluate_number_field_condition(condition, (; degree = d, num_ram = d)), reference)
            @test actual == filter(predicate, reference)
            @test occursin("WHERE", number_field_condition_sql(parameter, condition))
        end

        prime_sets = [BigInt[], BigInt[2], BigInt[3], BigInt[2, 3], BigInt[3, 2],
                      BigInt[2, 2, 3], BigInt[2, 5], BigInt[3, 5], BigInt[2, 3, 5]]
        for (criterion, predicate) in ramified_condition_cases(convert_value)
            condition = number_field_condition(:ramified, criterion)
            actual = filter(x -> evaluate_number_field_condition(condition, (; ramps = x)), prime_sets)
            @test actual == filter(predicate, prime_sets)
            @test occursin("WHERE", number_field_condition_sql(:ramified, condition))
        end
    end
end

function test_number_field_integer_ranges(convert_value)
    @testset "Number field integer ranges: $(typeof(convert_value(0)))" begin
        for parameter in (:degree, :ramified_prime_count), (lb, ub) in ((0, 3), (3, 2), (-3, 3))
            condition = number_field_condition(parameter, in(convert_value(lb):convert_value(ub)))
            for d in -4:4
                @test evaluate_number_field_condition(condition, (; degree = d, num_ram = d)) == (lb <= d <= ub)
            end
            sql = number_field_condition_sql(parameter, condition)
            @test occursin(lb > ub ? "WHERE FALSE" : "BETWEEN", sql)
        end
    end
end

function test_large_number_field_conditions(convert_value)
    @testset "Large number field operands: $(typeof(convert_value(0)))" begin
        value = big(2)^128 + 1
        for parameter in (:degree, :ramified_prime_count), criterion in
                (identity, ==, <, <=, >, >=, x -> in([-x, x]), x -> in(-x:x))
            condition = number_field_condition(parameter, criterion(convert_value(value)))
            expected = number_field_condition(parameter, criterion(value))
            sql = number_field_condition_sql(parameter, condition)
            @test sql == number_field_condition_sql(parameter, expected)
            @test sizeof(sql) < 400
        end
        for op in (==, v -> Base.Fix2(issetequal, v), issubset, LMFDBLite.includes)
            condition = number_field_condition(:ramified, op(convert_value.([2, value])))
            @test evaluate_number_field_condition(condition, (; ramps = BigInt[2, value]))
            sql = number_field_condition_sql(:ramified, condition)
            @test occursin(string(value), sql)
            @test sizeof(sql) < 400
        end
    end
end

@testset "Number field parameter definitions without a database" begin
    for T in (Int, Int32, BigInt, ConvertibleDiscriminant)
        test_number_field_conditions(T)
    end
    for T in (Int, Int32, BigInt)
        test_number_field_integer_ranges(T)
    end
    test_large_number_field_conditions(BigInt)

    @testset "Compact machine-integer ranges" begin
        for parameter in (:degree, :ramified_prime_count), r in
                (0:10^9, typemin(Int):typemax(Int), 4:-1:0)
            condition = number_field_condition(parameter, in(r))
            sql = number_field_condition_sql(parameter, condition)
            @test condition isa LMFDBLite.PredC
            @test occursin("BETWEEN", sql)
            @test sizeof(sql) < 400
        end
    end

    @testset "Operator and operand validation" begin
        scalar_invalid = (nothing, 1.5, ==(1.5), ==([2]), in(1), in([2, 1.5]),
                          in(1:2:5), !=(2), LMFDBLite.includes([2]), issubset([2]))
        set_invalid = (nothing, [2, 1.5], ==(2), >([2, 3]), in([2, 3]),
                       LMFDBLite.includes([missing]), LMFDBLite.includes(2:3))
        for parameter in (:degree, :ramified_prime_count, :ramified)
            invalid = parameter == :ramified ? set_invalid : scalar_invalid
            valid = parameter == :ramified ? LMFDBLite.includes(Int[]) : in(Int[])
            for bad in invalid, criterion in (bad, allof(valid, bad),
                                             anyof(valid, allof(valid, bad)))
                err = try
                    number_field_condition(parameter, criterion)
                catch e
                    e
                end
                @test err isa ArgumentError
                @test occursin("`$parameter`", sprint(showerror, err))
            end
        end
    end

    @testset "Class group equality retains its order" begin
        for parameter in (:class_group, :narrow_class_group)
            condition = number_field_condition(parameter, [2, 3])
            reversed = number_field_condition(parameter, [3, 2])
            @test condition isa LMFDBLite.PredC
            @test condition.op.f === (==)
            @test condition.op.x != reversed.op.x
            @test number_field_condition_sql(parameter, condition) != number_field_condition_sql(parameter, reversed)
        end
    end
end

function test_live_number_field_conditions(conn)
    @testset "Number field parameter definitions against live records" begin
        selected = ["1.1.1.1", "2.0.4.1", "2.0.3.1", "2.2.12.1", "2.2.5.1"]
        bounds = (; label = in(selected))
        reference = LMFDBLite.search(conn, "nf_fields"; bounds...)
        labels(rows) = Set(r.label for r in rows)
        @test labels(reference) == Set(selected)
        @test any(r -> isempty(r.ramps), reference)
        test_live_signature_composition(conn, "nf_fields", reference)
        for T in (Int, Hecke.ZZ)
            for (parameter, column) in ((:degree, :degree), (:ramified_prime_count, :num_ram))
                for (criterion, predicate) in integer_condition_cases(T)
                    rows = LMFDBLite.search(conn, "nf_fields"; bounds..., parameter => criterion)
                    @test labels(rows) == labels(filter(r -> predicate(BigInt(getproperty(r, column))), reference))
                end
            end
            for (criterion, predicate) in ramified_condition_cases(T)
                rows = LMFDBLite.search(conn, "nf_fields"; bounds..., ramified = criterion)
                @test labels(rows) == labels(filter(r -> predicate(BigInt.(r.ramps)), reference))
            end
        end
        # The public dispatcher must reject unsupported operators before SQL execution.
        for (parameter, bad) in ((:degree, LMFDBLite.includes([2])),
                                 (:ramified_prime_count, issubset([2])), (:ramified, >([2, 3])))
            @test_throws ArgumentError LMFDBLite.search(conn, "nf_fields"; parameter => bad)
        end
    end
end
