using LMFDBLite
using DBInterface
using Test

@testset "LMFDBLite without Hecke" begin
    @test Base.PkgId(LMFDBLite).name == "LMFDBLite"
    @test parentmodule(LMFDBLite.LMFDBConnection) === LMFDBLite
    @test Base.get_extension(LMFDBLite, :LMFDBLiteHeckeExt) === nothing
    @test !isdefined(LMFDBLite, :Hecke)
    @test !isdefined(LMFDBLite, :number_field)
    @test !isdefined(LMFDBLite, :elliptic_curve)
    @test !isdefined(LMFDBLite, :genus)
    @test lmfdb === LMFDBLite.lmfdb
    @test includes === LMFDBLite.includes
    @test allof === LMFDBLite.allof
    @test anyof === LMFDBLite.anyof
    @test Set(names(LMFDBLite)) == Set((:LMFDBLite, :includes, :lmfdb, :reset!, :allof, :anyof))
    @test reset! === LMFDBLite.reset!
    @test hasmethod(reset!, Tuple{LMFDBLite.LMFDBConnection})
    @test isempty(methods(LMFDBLite.number_fields))
    @test isempty(methods(LMFDBLite.elliptic_curves))
    @test haskey(LMFDBLite._number_field_parameter_definitions(), :galois_group)
    @test haskey(LMFDBLite._elliptic_curve_parameter_definitions(), :conductor)
    @test hasmethod(LMFDBLite.count_number_fields, Tuple{LMFDBLite.LMFDBConnection})
    @test hasmethod(LMFDBLite.count_elliptic_curves, Tuple{LMFDBLite.LMFDBConnection})
    @test hasmethod(LMFDBLite.count_integer_lattices, Tuple{LMFDBLite.LMFDBConnection})
    @test hasmethod(LMFDBLite.count_genera, Tuple{LMFDBLite.LMFDBConnection})
end

include("parameter_consistency.jl")
include("connection_options.jl")
include("metadata.jl")
if haskey(ENV, "LMFDB_POSTGRES_BIN")
    include("metadata_postgresql.jl")
end
include("discriminants.jl")
include("number_field_conditions.jl")
include("composition.jl")
include("integer_ranges.jl")

include("search_inputs.jl")
