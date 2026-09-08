# Read-only integration tests, enabled explicitly by test/runtests.jl.
connection_options = Dict{Symbol, Any}(:connect_timeout => 15)
for key in (:host, :port, :dbname, :user, :password, :schema)
    env_key = "LMFDB_" * uppercase(string(key))
    if haskey(ENV, env_key)
        connection_options[key] = ENV[env_key]
    end
end

@testset "LMFDB live database tests" begin
    conn = LMFDBLite.LMFDBConnection(; connection_options...)
    try
        test_lazy_metadata(conn)
        @test reset!(conn) === nothing
        @test isopen(conn)
        @test sprint(show, conn) ==
            "LMFDB database connection to $(conn.env.host):$(conn.env.port)"
        @test sprint(show, MIME"text/plain"(), conn) ==
            "Connection to the LMFDB database\n" *
            "  host: $(conn.env.host)\n" *
            "  port: $(conn.env.port)"
        test_number_field_parameter_consistency(conn)
        include("number_fields.jl")
        test_number_fields(conn)
        include("lattices.jl")
        test_lattices_and_genera(conn)
        include("elliptic_curves.jl")
        test_elliptic_curves(conn)
        include("elliptic_curves_number_fields.jl")
        test_elliptic_curves_over_number_fields(conn)
    finally
        DBInterface.close!(conn)
    end
end
