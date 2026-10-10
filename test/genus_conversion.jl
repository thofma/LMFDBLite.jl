function has_cached_genus_representatives(G::Hecke.ZZGenus)
    return hasfield(typeof(G), :_representatives) ?
        isdefined(G, :_representatives) : Hecke.has_attribute(G, :representatives)
end

@testset "Integer genus conversion without a database" begin
    ext = Base.get_extension(LMFDBLite, :LMFDBLiteHeckeExt)
    record = (; label = "1.1.1.3", rank = 1, rep = BigInt[1], class_number = 1)
    lattice_record = (; label = "1.1.1.3.1", rank = 1, gram = BigInt[1],
                      genus_label = record.label)
    lattices = [ext._lattice_from_record(lattice_record)]
    G = ext._genus_from_record(record, lattices)

    @test Hecke.get_attribute(G, :lmfdb_label) == record.label
    @test has_cached_genus_representatives(G)
    @test Hecke.representatives(G) === lattices
    @test Hecke.get_attribute.(Hecke.representatives(G), :lmfdb_label) == [lattice_record.label]

    # Empty, incomplete, or unverified sets must not replace Hecke's cache.
    for (altered, representatives) in
            ((record, Hecke.ZZLat[]),
             (merge(record, (; class_number = 2)), lattices),
             (merge(record, (; class_number = missing)), lattices))
        result = ext._genus_from_record(altered, representatives)
        @test result == G
        @test !has_cached_genus_representatives(result)
    end
end
