function test_lattices_and_genera(conn::LMFDBLite.LMFDBConnection)
    labels(rows) = Set(r.label for r in rows)
    @testset "Quadratic parameter schemas" begin
        for table in ("lat_lattices_new", "lat_genera")
            @test isnothing(LMFDBLite.check_search_parameters(conn, table))
            layout = LMFDBLite.table_layout(conn, table)
            @testset "$table: $parameter" for (parameter, spec) in LMFDBLite._search_parameter_definitions(table)
                @test isnothing(LMFDBLite._check_parameter_schema(layout, table, parameter, spec))
            end
        end
    end

    @testset "Shared lattice and genus filters: $table" for table in ("lat_lattices_new", "lat_genera")
        reference = LMFDBLite.search(conn, table; rank = 1, limit = 3)
        @test length(reference) == 3
        pool = [r.label for r in reference]
        for criterion in (1, ==(1), in(1:2), >=(1) & <=(2))
            rows = LMFDBLite.search(conn, table; label = in(pool), rank = criterion)
            @test labels(rows) == Set(pool)
        end
        for (criterion, expected) in [((1, 0), Set(pool)), (==([1, 0]), Set(pool)),
                                      ((1, 1), Set{String}()), ((0, 1), Set{String}())]
            rows = LMFDBLite.search(conn, table; label = in(pool), signature = criterion)
            @test labels(rows) == expected
        end
        for value in (true, false)
            rows = LMFDBLite.search(conn, table; label = in(pool), is_even = value)
            @test labels(rows) == labels(filter(r -> r.is_even === value, reference))
        end
        @test length(LMFDBLite.search(conn, table; label = in(pool), limit = 1)) == 1
        @test isempty(LMFDBLite.search(conn, table; label = in(pool), limit = 0))
        @test isempty(LMFDBLite.search(conn, table; label = in(String[])))
        @test LMFDBLite.count(conn, table; label = in(pool)) == 3
        type_count = table == "lat_lattices_new" ?
            LMFDBLite.count_integer_lattices(conn; label = in(pool)) :
            LMFDBLite.count_genera(conn; label = in(pool))
        @test type_count == 3
        @test LMFDBLite.count(conn, table; label = in(pool), limit = 1) == 1
        @test LMFDBLite.count(conn, table; label = in(pool), limit = 0) == 0
        @test_throws ArgumentError LMFDBLite.search(conn, table; degree = 2, limit = 1)
        @test_throws ArgumentError LMFDBLite.search(conn, table; signature = (-1, 2), limit = 1)
        @test_throws ErrorException LMFDBLite.search(conn, table; rank = LMFDBLite.includes([1]), limit = 1)
        @test_throws ErrorException LMFDBLite.search(conn, table; signature = <((1, 0)), limit = 1)
    end

    @testset "Lattice filters and Hecke conversion" begin
        reference = LMFDBLite.search(conn, "lat_lattices_new"; rank = 1, limit = 3)
        pool = [r.label for r in reference]
        sample = first(reference)
        cases = [(:level, :level, BigInt(sample.level)),
                 (:class_number, :class_number, BigInt(sample.class_number)),
                 (:minimum, :minimum, BigInt(sample.minimum)),
                 (:automorphism_group_order, :aut_size, BigInt(sample.aut_size)),
                 (:automorphism_group, :aut_label, sample.aut_label),
                 (:dual_determinant, :dual_det, Float64(sample.dual_det)),
                 (:dual_kissing_number, :dual_kissing, BigInt(sample.dual_kissing)),
                 (:kissing_number, :kissing, BigInt(sample.kissing)),
                 (:festi_veniani_index, :festi_veniani_index, BigInt(sample.festi_veniani_index)),
                 (:gram_matrix, :gram, Int.(sample.gram)),
                 (:disc_group_invs, :discriminant_group_invs, Int.(sample.discriminant_group_invs))]
        for (parameter, column, criterion) in cases
            rows = LMFDBLite.search(conn, "lat_lattices_new"; label = in(pool), parameter => criterion)
            @test !isempty(rows)
            @test labels(rows) == labels(filter(reference) do r
                value = getproperty(r, column)
                !ismissing(value) && (parameter == :dual_determinant ? Float64(value) : value) == criterion
            end)
        end

        lattices = LMFDBLite.integer_lattices(conn; label = in(pool), signature = (1, 0))
        @test lattices isa Vector{Hecke.ZZLat}
        @test Set(Hecke.get_attribute(L, :lmfdb_label) for L in lattices) == Set(pool)
        records = Dict(r.label => r for r in reference)
        for L in lattices
            record = records[Hecke.get_attribute(L, :lmfdb_label)]
            @test Hecke.gram_matrix(L) == Hecke.matrix(Hecke.ZZ, 1, 1, Int.(record.gram))
            @test Hecke.get_attribute(L, :lmfdb_genus_label) == record.genus_label
        end
        L = LMFDBLite.integer_lattice(conn, sample.label)
        @test Hecke.get_attribute(L, :lmfdb_label) == sample.label
        @test Hecke.gram_matrix(Hecke.integer_lattice(conn, sample.label)) == Hecke.gram_matrix(L)
        @test length(LMFDBLite.integer_lattices(conn; label = in(pool), limit = 1)) == 1
        @test isempty(LMFDBLite.integer_lattices(conn; rank = 1, limit = 0))
        @test isempty(LMFDBLite.integer_lattices(conn; label = in(String[])))
        @test_throws ErrorException LMFDBLite.integer_lattice(conn, "no-such-lattice")
    end

    @testset "Genus filters and representatives" begin
        reference = LMFDBLite.search(conn, "lat_genera"; rank = 1, limit = 3)
        pool = [r.label for r in reference]
        sample = first(reference)
        for (parameter, column, criterion) in
                [(:determinant, :det, sample.det),
                 (:discriminant, :disc, sample.disc),
                 (:representative_gram_matrix, :rep, Int.(sample.rep)),
                 (:discriminant_form, :discriminant_form, Int.(sample.discriminant_form))]
            rows = LMFDBLite.search(conn, "lat_genera"; label = in(pool), parameter => criterion)
            @test !isempty(rows)
            @test labels(rows) == labels(filter(r -> getproperty(r, column) == criterion, reference))
        end
        rows = LMFDBLite.search(conn, "lat_genera"; label = in(pool), mass = 1//2)
        @test labels(rows) == Set(pool)
        @test_throws ErrorException LMFDBLite.search(conn, "lat_genera"; mass = <(1//2), limit = 1)
        @test_throws ArgumentError LMFDBLite.search(conn, "lat_genera"; genus_label = sample.label, limit = 1)

        genera = LMFDBLite.genera(conn; label = in(pool), signature = (1, 0))
        @test genera isa Vector{Hecke.ZZGenus}
        @test Set(Hecke.get_attribute(G, :lmfdb_label) for G in genera) == Set(pool)
        records = Dict(r.label => r for r in reference)
        for G in genera
            record = records[Hecke.get_attribute(G, :lmfdb_label)]
            @test G == Hecke.genus(Hecke.matrix(Hecke.ZZ, 1, 1, Int.(record.rep)))
        end
        @test length(LMFDBLite.genera(conn; label = in(pool), limit = 1)) == 1
        @test isempty(LMFDBLite.genera(conn; rank = 1, limit = 0))
        @test isempty(LMFDBLite.genera(conn; label = in(String[])))
        @test_throws ErrorException Hecke.genus(conn, "no-such-genus")

        # This small genus has its complete representative set in the lattice table.
        label = "1.1.1.3"
        record = only(LMFDBLite.search(conn, "lat_genera"; label))
        lattice_records = LMFDBLite.search(conn, "lat_lattices_new"; genus_label = label)
        G = Hecke.genus(conn, label)
        @test Hecke.get_attribute(G, :lmfdb_label) == label
        @test length(lattice_records) == record.class_number == 1
        @test Hecke.has_attribute(G, :representatives)
        @test Set(Hecke.get_attribute(L, :lmfdb_label) for L in Hecke.representatives(G)) == labels(lattice_records)

        # A genus remains constructible if representatives are absent or incomplete.
        ext = Base.get_extension(LMFDBLite, :LMFDBLiteHeckeExt)
        for altered in (merge(record, (; label = "no-stored-representatives")),
                        merge(record, (; class_number = record.class_number + 1)))
            result = only(ext._genera_from_records(conn, [altered]))
            @test result == G
            @test !Hecke.has_attribute(result, :representatives)
        end
    end
end
