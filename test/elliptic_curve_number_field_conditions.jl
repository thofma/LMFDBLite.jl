@testset "Number field elliptic curve search conditions" begin
    table = "ec_nfcurves"
    definitions = LMFDBLite._search_parameter_definitions(table)
    @test definitions[:ainvs] == definitions[:a_invariants]
    @test definitions[:jinv] == definitions[:j_invariant]
    @test !haskey(definitions, :conductor)
    @test definitions[:conductor_norm][2] === LMFDBLite.SQL.bigint
    @test definitions[:torsion_structure][2] === LMFDBLite.SQL.jsonb
    @test definitions[:torsion_primes][2] === LMFDBLite.SQL.list{LMFDBLite.SQL.integer}

    # JSON equality must preserve the full signature, including its order.
    for input in ((2, 0), [2, 0], ==((2, 0)))
        condition = composition_condition(table, :signature, input)
        @test occursin("'[2, 0]'", composition_sql(table, :signature, condition))
    end
    combined = composition_condition(table, :signature, anyof((2, 0), (0, 1)))
    sql = composition_sql(table, :signature, combined)
    @test occursin("OR", sql)
    @test occursin("'[2, 0]'", sql)
    @test occursin("'[0, 1]'", sql)
    for bad in ((-1, 1), (0, 0), (2,), (1, 2, 3), (1.5, 0), <((2, 0)), in([(2, 0)]))
        test_input_error(table, :signature, anyof((2, 0), bad))
    end

    for (parameter, value, expected) in
            ((:torsion_structure, [2, 4], "'[2, 4]'"),
             (:torsion_primes, [2, 3], "'{2,3}'"),
             (:isogeny_degrees, [2, 3], "'{2,3}'"),
             (:a_invariants, "1,0;1,1;0,1;0,1;0,0", "'1,0;1,1;0,1;0,1;0,0'"),
             (:j_invariant, "51455/31,-106208/31", "'51455/31,-106208/31'"))
        condition = composition_condition(table, parameter, value)
        @test occursin(expected, composition_sql(table, parameter, condition))
    end
end
