# In-memory number field records let us count lookups without a database.
struct NumberFieldRecordSource
    records::Dict{String, NamedTuple}
    lookups::Vector{String}
end

function Hecke.number_field(source::NumberFieldRecordSource, label::String)
    push!(source.lookups, label)
    ext = Base.get_extension(LMFDBLite, :LMFDBLiteHeckeExt)
    return ext._number_field_from_record(source.records[label])
end

@testset "Number field elliptic curve conversion without a database" begin
    ext = Base.get_extension(LMFDBLite, :LMFDBLiteHeckeExt)
    source = NumberFieldRecordSource(Dict{String, NamedTuple}(
        "2.2.5.1" => (label = "2.2.5.1", coeffs = [-1, -1, 1]),
        "3.1.23.1" => (label = "3.1.23.1", coeffs = [1, 0, -1, 1])), String[])
    # Reference records from the public ec_nfcurves table, with its exact basis.
    quadratic = (label = "2.2.5.1-31.1-a1", field_label = "2.2.5.1",
                 ainvs = "1,0;1,1;0,1;0,1;0,0")
    cubic = (label = "3.1.23.1-89.1-A1", field_label = "3.1.23.1",
             ainvs = "1,1,0;-1,-1,-1;0,1,1;0,0,-1;1,0,-1")
    other_quadratic = (label = "2.2.5.1-599.1-b1", field_label = "2.2.5.1",
                       ainvs = "1,0;1,1;0,0;-3,-1;-7,-8")

    @test isempty(ext._number_field_elliptic_curves(source, NamedTuple[]))
    @test isempty(source.lookups)
    curves = ext._number_field_elliptic_curves(source, [quadratic, cubic, other_quadratic])
    @test source.lookups == ["2.2.5.1", "3.1.23.1"]
    @test get_attribute.(curves, :lmfdb_label) == [quadratic.label, cubic.label, other_quadratic.label]
    K, L = base_field(curves[1]), base_field(curves[2])
    @test base_field(curves[3]) === K
    @test get_attribute(K, :lmfdb_label) == quadratic.field_label
    @test get_attribute(L, :lmfdb_label) == cubic.field_label
    a, b = gen(K), gen(L)
    @test a^2 - a - 1 == 0
    @test b^3 - b^2 + 1 == 0
    @test collect(a_invariants(curves[1])) == [K(1), 1 + a, a, a, K(0)]
    @test collect(a_invariants(curves[2])) == [1 + b, -1 - b - b^2, b + b^2, -b^2, 1 - b^2]
    @test j_invariant(curves[1]) == (51455 - 106208a)//31
    @test j_invariant(curves[2]) == (275391 - 337201b + 197037b^2)//89

    @test ext._parse_number_field_element(L, "-1/2,3/7,-5/11") == -L(1)//2 + 3b//7 - 5b^2//11
    large = big(2)^200 + 123
    @test ext._parse_number_field_element(K, "$(large)/3,-$(large)/7") == K(QQ(large, 3)) - QQ(large, 7)*a
    @test ext._parse_number_field_element(K, "5") == K(5)
    for invalid in ("", "1,", "1,2,3", "1/0", "1/2/3", "a", "1+1", "1//2")
        @test_throws ArgumentError ext._parse_number_field_element(K, invalid)
    end
    @test_throws ArgumentError ext._number_field_elliptic_curve_from_record(
        merge(quadratic, (ainvs = "1;2;3;4",)), K)

    # Nonintegral coefficients must also work through the complete constructor.
    fractional = merge(quadratic, (ainvs = "0;0;0;-1/2,1/3;1/7,-1/11",))
    E = ext._number_field_elliptic_curve_from_record(fractional, K)
    @test collect(a_invariants(E)) == [K(0), K(0), K(0), -K(1)//2 + a//3, K(1)//7 - a//11]
end
