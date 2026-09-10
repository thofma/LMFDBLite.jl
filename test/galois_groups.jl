@testset "Galois group code parsing" begin
    @test LMFDBLite._galois_group_alias_seed("C3") == "3T1"
    @test LMFDBLite._galois_group_alias_seed("C32") == "32T33"
    @test LMFDBLite._galois_group_alias_seed("A5") == "5T4"
    @test LMFDBLite._galois_group_alias_seed("S5") == "5T5"
    @test LMFDBLite._galois_group_alias_seed("D4") == "4T3"
    @test LMFDBLite._galois_group_alias_seed("PSL(2,7)") == "7T5"
    @test LMFDBLite._galois_group_alias_seed("C2XC4") == "8T2"
    @test isnothing(LMFDBLite._galois_group_alias_seed("UNKNOWN"))

    @test LMFDBLite._split_galois_group_codes("C3,[8,3],PSL(2,7)") ==
          ["C3", "[8,3]", "PSL(2,7)"]
    for invalid in ("", ",C3", "C3,", "[8,3", "8,3]")
        @test_throws ArgumentError LMFDBLite._split_galois_group_codes(invalid)
    end
end
