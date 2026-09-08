# Public-mirror smoke test; independent of LMFDB_* connection overrides.
using LMFDBLite, DBInterface, Test

@testset "Cached default connection" begin
    cached = LMFDBLite.lmfdb()
    @test cached isa LMFDBLite.LMFDBConnection
    @test isopen(cached)
    @test LMFDBLite.lmfdb() === cached
    @test all(fetch(task) === cached for task in
        [Threads.@spawn LMFDBLite.lmfdb() for _ in 1:4])
    DBInterface.close!(cached)
    @test !isopen(cached)
    replacement = LMFDBLite.lmfdb()
    @test replacement !== cached
    @test isopen(replacement)
    DBInterface.close!(replacement)
end
