using Hecke

@test LMFDBLite.UI.require_object_conversions() === nothing

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

    rows = [
        (; label = "2.2.5.1", coeffs = BigInt[-1, -1, 1]),
        (; label = "2.2.8.1", coeffs = BigInt[-2, 0, 1]),
    ]
    fields = LMFDBLite._number_fields_from_rows(rows)
    @test fields isa Vector{Hecke.AbsSimpleNumField}
    @test Hecke.get_attribute.(fields, :lmfdb_label) == getproperty.(rows, :label)
    @test Hecke.defining_polynomial.(fields) ==
          map(row -> Hecke.Globals.Qx(BigInt.(row.coeffs)), rows)

    converters = LMFDBLite.UI.default_result_converters()
    curve_row = (; lmfdb_label = "11.a1", ainvs = BigInt[0, -1, 1, -10, -20])
    curves = converters[:elliptic_curves](nothing, [curve_row])
    @test length(curves) == 1
    @test Hecke.get_attribute(only(curves), :lmfdb_label) == curve_row.lmfdb_label
    lattice_row = (; label = "1.1.2.1.1", rank = 1, gram = BigInt[2], genus_label = missing)
    lattices = converters[:integer_lattices](nothing, [lattice_row])
    @test length(lattices) == 1
    @test Hecke.get_attribute(only(lattices), :lmfdb_label) == lattice_row.label
    @test isempty(converters[:elliptic_curves_number_fields](nothing, NamedTuple[]))
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
