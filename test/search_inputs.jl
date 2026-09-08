function test_input_error(table, parameter, value)
    err = try
        composition_condition(table, parameter, value)
    catch e
        e
    end
    @test err isa ArgumentError
    if err isa ArgumentError
        @test occursin("`$parameter`", sprint(showerror, err))
    end
end

@testset "Consistent input validation for transformed parameters" begin
    examples = Dict(
        String => ("sample", Any[42, missing, ["a"]]),
        Bool => (true, Any[2, missing, "true"]),
        Float64 => (1.5, Any["bad", missing, [1.0]]),
        Vector{BigInt} => ([2, 3], Any[2, (2, 3), ["bad"], 1:10^9]),
        Rational{BigInt} => (2//3, Any["bad", missing, [2, 3]]),
    )
    for table in ("nf_fields", "ec_curvedata", "lat_lattices_new", "lat_genera")
        for (parameter, spec) in LMFDBLite._search_parameter_definitions(table)
            T, _, _, _, allowed = spec
            haskey(examples, T) || continue
            good, invalid = examples[T]
            bare = composition_condition(table, parameter, good)
            explicit = composition_condition(table, parameter, ==(good))
            @test composition_sql(table, parameter, bare) == composition_sql(table, parameter, explicit)
            for bad in invalid, value in (bad, ==(bad), allof(good, ==(bad)), anyof(good, ==(bad)))
                test_input_error(table, parameter, value)
            end
            unsupported = Base.Fix2(isequal, good)
            for value in (unsupported, allof(good, unsupported), anyof(good, unsupported))
                test_input_error(table, parameter, value)
            end
            if in in allowed
                for value in (in((good,)), in(Set([good])), in(good), in([good, first(invalid)]))
                    test_input_error(table, parameter, value)
                end
                empty = composition_condition(table, parameter, in([]))
                @test empty isa LMFDBLite.FalseC
                @test occursin("WHERE FALSE", composition_sql(table, parameter, empty))
                test_input_error(table, parameter, anyof(in([]), ==(first(invalid))))
            end
        end
    end
end
