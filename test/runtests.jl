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
    @test isempty(methods(LMFDBLite.number_fields))
    @test isempty(methods(LMFDBLite.elliptic_curves))
    @test haskey(LMFDBLite._number_field_parameters(), :galois_group)
    @test haskey(LMFDBLite._elliptic_curve_parameters(), :conductor)
    @test hasmethod(LMFDBLite.count_number_fields, Tuple{LMFDBLite.LMFDBConnection})
    @test hasmethod(LMFDBLite.count_elliptic_curves, Tuple{LMFDBLite.LMFDBConnection})
    @test hasmethod(LMFDBLite.count_integer_lattices, Tuple{LMFDBLite.LMFDBConnection})
    @test hasmethod(LMFDBLite.count_genera, Tuple{LMFDBLite.LMFDBConnection})
end

include("parameter_consistency.jl")

using Hecke

@testset "Hecke extension" begin
    @test Base.get_extension(LMFDBLite, :LMFDBLiteHeckeExt) !== nothing
    @test LMFDBLite.number_field === Hecke.number_field
    @test LMFDBLite.elliptic_curve === Hecke.elliptic_curve
    @test LMFDBLite.genus === Hecke.genus
    @test hasmethod(Hecke.number_field, Tuple{LMFDBLite.LMFDBConnection, String})
    @test hasmethod(LMFDBLite.number_fields, Tuple{LMFDBLite.LMFDBConnection})
    @test hasmethod(LMFDBLite.integer_lattice, Tuple{LMFDBLite.LMFDBConnection, String})
    @test hasmethod(LMFDBLite.genus, Tuple{LMFDBLite.LMFDBConnection, String})
    @test hasmethod(LMFDBLite.elliptic_curve, Tuple{LMFDBLite.LMFDBConnection, String})
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
    conn = LMFDBLite.LMFDBConnection(; connection_options...)
    try
        @testset "Cached default connection" begin
            cached = LMFDBLite.lmfdb()
            @test cached isa LMFDBLite.LMFDBConnection
            @test isopen(cached)
            @test LMFDBLite.lmfdb() === cached
            @test all(fetch(task) === cached for task in
                [Threads.@spawn LMFDBLite.lmfdb() for _ in 1:4])
            @test conn !== cached
            DBInterface.close!(cached)
            @test !isopen(cached)
            replacement = LMFDBLite.lmfdb()
            @test replacement !== cached
            @test isopen(replacement)
            DBInterface.close!(replacement)
        end
        test_number_field_parameter_consistency(conn)
        include("number_fields.jl")
        test_number_fields(conn)
        include("lattices.jl")
        test_lattices_and_genera(conn)
        include("elliptic_curves.jl")
        test_elliptic_curves(conn)
    finally
        DBInterface.close!(conn)
    end
end
