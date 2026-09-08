import FunSQL

function discriminant_condition(table, value)
    _, _, columns, builder, allowed = LMFDBLite._search_parameter_definitions(table)[:discriminant]
    condition = builder(columns, value, :discriminant, allowed)
    LMFDBLite._assert_parameter_columns(condition, columns, :discriminant)
    return condition
end

function discriminant_sql(table, condition)
    columns = table == "nf_fields" ? [:disc_abs, :disc_sign] : [:absD, :signD]
    query = FunSQL.From(FunSQL.SQLTable(Symbol(table); columns)) |>
            LMFDBLite._create_where([condition])
    return string(FunSQL.render(query; dialect = :postgresql))
end

evaluate_discriminant(c::LMFDBLite.PredC, row) = c.op(getproperty(row, c.symb))
evaluate_discriminant(c::LMFDBLite.FalseC, row) = false
evaluate_discriminant(c::LMFDBLite.AndC, row) =
    evaluate_discriminant(c.a, row) && evaluate_discriminant(c.b, row)
evaluate_discriminant(c::LMFDBLite.OrC, row) =
    evaluate_discriminant(c.a, row) || evaluate_discriminant(c.b, row)

function matches_discriminant(condition, table, d)
    row = table == "nf_fields" ? (; disc_abs = abs(d), disc_sign = sign(d)) :
                                (; absD = abs(d), signD = sign(d))
    return evaluate_discriminant(condition, row)
end

discriminant_node_count(::Union{LMFDBLite.PredC, LMFDBLite.FalseC}) = 1
discriminant_node_count(c::Union{LMFDBLite.AndC, LMFDBLite.OrC}) =
    1 + discriminant_node_count(c.a) + discriminant_node_count(c.b)

# This type deliberately has no Integer supertype or arithmetic methods.
struct ConvertibleDiscriminant
    value::BigInt
end
Base.BigInt(x::ConvertibleDiscriminant) = x.value

function test_discriminant_inputs(convert_value)
    @testset "Discriminant operands: $(typeof(convert_value(0)))" begin
        reference = BigInt[d for d in -20:20 if d != 0]
        append!(reference, [BigInt(typemin(Int)), BigInt(typemax(Int)), -big(2)^128, big(2)^128])
        values = convert_value.([-4, 0, 5, 5])
        empty_values = similar(values, 0)
        cases = Any[
            (in(values), d -> d in [-4, 0, 5]),
            (in(view(values, 1:2)), d -> d in [-4, 0]),
            (in(empty_values), d -> false),
            (allof(>=(convert_value(-4)), <=(convert_value(5))), d -> -4 <= d <= 5),
            (allof(>=(convert_value(-4)), <=(convert_value(5)), in(values)), d -> d in [-4, 0, 5]),
            (anyof(==(convert_value(-4)), ==(convert_value(5)), ==(convert_value(8))), d -> d in [-4, 5, 8]),
            (anyof(==(convert_value(-4)), ==(convert_value(5))), d -> d in [-4, 5]),
            (allof(anyof(==(convert_value(-4)), ==(convert_value(5))),
                   >=(convert_value(0))), d -> d == 5),
            (anyof(allof(>=(convert_value(-8)), <=(convert_value(-3))),
                   allof(>(convert_value(3)), <(convert_value(8)))),
             d -> -8 <= d <= -3 || 3 < d < 8),
            (anyof(in(empty_values), ==(convert_value(-4))), d -> d == -4),
            (allof(in(empty_values), ==(convert_value(-4))), d -> false),
        ]
        for bound in (-4, 0, 5)
            push!(cases, (convert_value(bound), ==(bound)))
            for op in (==, <, <=, >, >=)
                push!(cases, (op(convert_value(bound)), op(bound)))
            end
        end
        for table in ("nf_fields", "ec_curvedata"), (criterion, predicate) in cases
            condition = discriminant_condition(table, criterion)
            @test filter(d -> matches_discriminant(condition, table, d), reference) == filter(predicate, reference)
            @test occursin("WHERE", discriminant_sql(table, condition))
        end
    end
end

function test_discriminant_ranges(convert_value)
    @testset "Discriminant ranges: $(typeof(convert_value(0)))" begin
        reference = BigInt[d for d in -20:20 if d != 0]
        for table in ("nf_fields", "ec_curvedata"), (lb, ub) in
                ((-8, -3), (3, 8), (-8, 8), (0, 0), (3, 2), (-2, -3))
            criterion = in(convert_value(lb):convert_value(ub))
            condition = discriminant_condition(table, criterion)
            @test filter(d -> matches_discriminant(condition, table, d), reference) ==
                  filter(d -> lb <= d <= ub, reference)
            sql = discriminant_sql(table, condition)
            @test sizeof(sql) < 600
            if lb > ub
                @test condition isa LMFDBLite.FalseC
                @test occursin("WHERE FALSE", sql)
            end
        end
    end
end

@testset "Signed discriminants without a database" begin
    for T in (Int, Int32, BigInt, ConvertibleDiscriminant)
        test_discriminant_inputs(T)
    end
    for T in (Int, Int32, BigInt)
        test_discriminant_ranges(T)
    end

    @testset "Intervals agree with direct signed comparisons" begin
        reference = BigInt[d for d in -20:20 if d != 0]
        for table in ("nf_fields", "ec_curvedata"), T in (Int, BigInt), lb in -20:20, ub in -20:20
            condition = discriminant_condition(table, in(T(lb):T(ub)))
            @test filter(d -> matches_discriminant(condition, table, d), reference) ==
                  filter(d -> lb <= d <= ub, reference)
        end
    end

    @testset "Compact ranges and integer extrema" begin
        for table in ("nf_fields", "ec_curvedata")
            ranges = (-10^9:10^9, -(big(10)^30):big(10)^30,
                      typemin(Int):typemax(Int), typemin(Int):(typemin(Int) + 2),
                      (typemax(Int) - 2):typemax(Int), -8:1:8, 8:-1:-8)
            for r in ranges
                condition = discriminant_condition(table, in(r))
                sql = discriminant_sql(table, condition)
                @test discriminant_node_count(condition) <= 7
                @test sizeof(sql) < 600
                @test occursin("BETWEEN", sql)
                @test !occursin(" IN ", sql)
                lb, ub = minmax(BigInt(first(r)), BigInt(last(r)))
                for d in (lb - 1, lb, lb + 1, big(-1), big(1), ub - 1, ub, ub + 1)
                    d == 0 && continue
                    @test matches_discriminant(condition, table, d) == (lb <= d <= ub)
                end
            end
            for bound in (typemin(Int), typemax(Int)), op in (==, <, <=, >, >=)
                condition = discriminant_condition(table, op(bound))
                for d in (BigInt(bound) - 1, BigInt(bound), BigInt(bound) + 1)
                    @test matches_discriminant(condition, table, d) == op(d, BigInt(bound))
                end
            end
            condition = discriminant_condition(table, in(Int[]))
            @test condition isa LMFDBLite.FalseC
            @test occursin("WHERE FALSE", discriminant_sql(table, condition))
        end
    end

    @testset "Invalid operands and nested operators" begin
        invalid = (nothing, missing, :bad, "bad", 1.5, ==(1.5), in([1, 1.5]),
                   in(1), in(Set([-4, 5])), in(-3:2:3), in(big(-3):big(2):big(3)),
                   !=(-4), LMFDBLite.includes([-4, 5]))
        for table in ("nf_fields", "ec_curvedata"), bad in invalid
            # Even a branch made irrelevant by empty membership must be validated.
            for criterion in (bad, allof(in(Int[]), bad),
                              anyof(==(1), allof(>=(0), bad)))
                err = try
                    discriminant_condition(table, criterion)
                catch e
                    e
                end
                @test err isa ArgumentError
                @test occursin("`discriminant`", sprint(showerror, err))
            end
        end
    end
end

function test_live_discriminants(conn, table, reference; bounds...)
    @testset "Signed discriminants: $table" begin
        signed_value(r) = table == "nf_fields" ? BigInt(r.disc_sign) * BigInt(r.disc_abs) :
                                               BigInt(r.signD) * BigInt(r.absD)
        labels(rows) = Set(table == "nf_fields" ? r.label : r.lmfdb_label for r in rows)
        @test !isempty(reference)
        a, b = extrema(signed_value.(reference))
        @test a < 0 < b
        cases = [
            (Int(a), ==(a)), (==(Int(a)), ==(a)), (==(Hecke.ZZ(a)), ==(a)),
            (<(Int(a)), <(a)), (<=(Int(a)), <=(a)), (>(Int(a)), >(a)), (>=(Int(a)), >=(a)),
            (in(Int.([a, b])), d -> d in (a, b)),
            (in(Hecke.ZZ.([a, b])), d -> d in (a, b)),
            (in(Int[]), d -> false), (in(Hecke.ZZRingElem[]), d -> false),
            (in(Int(a):Int(b)), d -> a <= d <= b),
            (allof(>=(Hecke.ZZ(a)), <=(Hecke.ZZ(b))), d -> a <= d <= b),
            (anyof(==(Int(a)), ==(Hecke.ZZ(b))), d -> d in (a, b)),
            (allof(anyof(==(Int(a)), ==(Hecke.ZZ(b))), >(Int(a))), d -> d == b && d > a),
        ]
        for (criterion, predicate) in cases
            rows = LMFDBLite.search(conn, table; bounds..., discriminant = criterion)
            @test labels(rows) == labels(filter(r -> predicate(signed_value(r)), reference))
        end
    end
end
