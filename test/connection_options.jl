import LibPQ

@testset "Connection values round-trip through libpq" begin
    defaults = (; host = "localhost", port = "5432", dbname = "test",
                user = "test", password = "dummy")
    values = ["", "plain", "a b", " a ", "a'b", "'a'", "a\\b", "a\\'b",
              "\t\n", "Grüße λ", "dummy user=changed", "dummy\nsslmode=disable"]
    keys = (:host, :port, :dbname, :user, :password, :sslmode, :sslrootcert, :sslcert, :sslkey)
    for key in keys, value in values
        options = merge(defaults, NamedTuple{(key,)}((value,)))
        parsed = Dict(ci.keyword => ci.val for ci in LibPQ.conninfo(
            LMFDBLite._connection_string(; options...)))
        @test parsed[string(key)] == value
        # A value must never introduce or overwrite a second connection option.
        for (other, expected) in pairs(options)
            @test parsed[string(other)] == expected
        end
    end
    parsed = Dict(ci.keyword => ci.val for ci in LibPQ.conninfo(
        LMFDBLite._connection_string(; defaults..., sslmode = nothing)))
    @test ismissing(parsed["sslmode"])
    @test !haskey(parsed, "connect_timeout") || ismissing(parsed["connect_timeout"])
    @test occursin("port='5432'", LMFDBLite._connection_string(; merge(defaults, (; port = 5432))...))

    for key in keys
        options = merge(defaults, NamedTuple{(key,)}(("secret\0value",)))
        err = try
            LMFDBLite._connection_string(; options...)
        catch e
            e
        end
        @test err isa ArgumentError
        @test occursin(string(key), sprint(showerror, err))
        @test !occursin("secret", sprint(showerror, err))
    end
    # Validation happens before any attempt to connect.
    for timeout in (-1, Inf, NaN, "5", nothing)
        @test_throws ArgumentError LMFDBLite.LMFDBConnection(; connect_timeout = timeout)
    end
end
