using Hecke

@test LMFDBLite.UI.require_number_fields() === nothing

include("elliptic_curve_number_field_conversion.jl")

@testset "Hecke extension" begin
    @test Base.get_extension(LMFDBLite, :LMFDBLiteHeckeExt) !== nothing
    @test !isdefined(LMFDBLite, :number_field)
    @test !isdefined(LMFDBLite, :elliptic_curve)
    @test !isdefined(LMFDBLite, :genus)
    @test hasmethod(Hecke.number_field, Tuple{LMFDBLite.LMFDBConnection, String})
    @test hasmethod(Hecke.elliptic_curve, Tuple{LMFDBLite.LMFDBConnection, String})
    @test hasmethod(Hecke.genus, Tuple{LMFDBLite.LMFDBConnection, String})
    @test hasmethod(LMFDBLite.number_fields, Tuple{LMFDBLite.LMFDBConnection})
    @test hasmethod(LMFDBLite.elliptic_curves_over_number_fields, Tuple{LMFDBLite.LMFDBConnection})
    @test hasmethod(LMFDBLite.integer_lattice, Tuple{LMFDBLite.LMFDBConnection, String})
end

# ZZRingElem is also Oscar's integer type; these tests need no database.
test_discriminant_inputs(Hecke.ZZ)
test_discriminant_ranges(Hecke.ZZ)
test_number_field_conditions(Hecke.ZZ)
test_number_field_integer_ranges(Hecke.ZZ)
test_large_number_field_conditions(Hecke.ZZ)
test_composition_inputs(Hecke.ZZ)
test_integer_ranges(Hecke.ZZ)
test_large_integer_ranges(Hecke.ZZ, big(10)^30)

@testset "ZZRingElem discriminants beyond machine integers" begin
    value = big(2)^128 + 1
    for table in ("nf_fields", "ec_curvedata"), criterion in
            (identity, ==, <, <=, >, >=, x -> in([-x, x]), x -> in(-x:x))
        condition = discriminant_condition(table, criterion(Hecke.ZZ(value)))
        expected = discriminant_condition(table, criterion(value))
        sql = discriminant_sql(table, condition)
        @test sql == discriminant_sql(table, expected)
        @test sizeof(sql) < 700
    end
end
