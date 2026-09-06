using LMFDBLite
using DBInterface
using Test

@testset "LMFDBLite without Hecke" begin
    @test Base.PkgId(LMFDBLite).name == "LMFDBLite"
    @test parentmodule(LMFDBLite.LMFDBConnection) === LMFDBLite
    @test Base.get_extension(LMFDBLite, :LMFDBLiteHeckeExt) === nothing
    @test !isdefined(LMFDBLite, :Hecke)
    @test isempty(methods(LMFDBLite.number_fields))
    @test haskey(LMFDBLite._new_number_field_parameters(), :galois_group)
end

include("parameter_consistency.jl")

using Hecke

@testset "Hecke extension" begin
    @test Base.get_extension(LMFDBLite, :LMFDBLiteHeckeExt) !== nothing
    @test hasmethod(LMFDBLite.number_fields, Tuple{LMFDBLite.LMFDBConnection})
    @test hasmethod(LMFDBLite.integer_lattice, Tuple{LMFDBLite.LMFDBConnection, String})
    @test hasmethod(LMFDBLite.genus, Tuple{LMFDBLite.LMFDBConnection, String})
end

# Use the package's default public database, with optional connection overrides.
connection_options = Dict{Symbol, String}()
for key in (:host, :port, :dbname, :user, :password)
    env_key = "LMFDB_" * uppercase(string(key))
    if haskey(ENV, env_key)
        connection_options[key] = ENV[env_key]
    end
end

@testset "LMFDB live database tests" begin
    db = LMFDBLite.LMFDBConnection(; connection_options...)
    try
        test_number_field_parameter_consistency(db)
        include("number_fields.jl")
        test_number_fields(db)
        include("lattices.jl")
        test_lattices_and_genera(db)
    finally
        DBInterface.close!(db)
    end
end
