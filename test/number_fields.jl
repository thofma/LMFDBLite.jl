function test_number_fields(db)
    @testset "Number field Galois group search" begin
        @testset "Equality: $filter" for filter in ("4T2", ==("4T2"))
            rows = LMFDBLite.new_search(db, "nf_fields";
                galois_group = filter, limit = 5)

            @test rows isa Vector{<:NamedTuple}
            @test !isempty(rows)
            @test length(rows) <= 5
            @test all(r -> r.galois_label == "4T2" && r.degree == 4, rows)
        end

        @testset "Membership" begin
            # This small range contains both cyclic and noncyclic cubic fields.
            labels = ["3T1", "3T2"]
            rows = LMFDBLite.new_search(db, "nf_fields";
                galois_group = in(labels), degree = 3,
                discriminant = in(-100:100), limit = 100)

            @test !isempty(rows)
            @test length(rows) < 100
            @test Set(r.galois_label for r in rows) == Set(labels)
            @test all(r -> r.degree == 3, rows)
            @test all(r -> -100 <= r.disc_sign * r.disc_abs <= 100, rows)
        end

        @testset "Combined number field parameters" begin
            parameters = (;
                discriminant = in(-110:3300),
                class_group = [2, 2], ramified = LMFDBLite.includes([2, 3]),
                degree = 2)
            rows = LMFDBLite.new_search(db, "nf_fields"; parameters...)
            fields = LMFDBLite.number_fields(db; parameters..., limit = 10)
            records = Dict(r.label => r for r in rows)

            @test rows isa Vector{<:NamedTuple}
            @test !isempty(rows)
            @test fields isa Vector{Hecke.AbsSimpleNumField}
            @test length(fields) == min(length(rows), 10)
            @test all(fields) do K
                record = records[Hecke.get_attribute(K, :lmfdb_label)]
                Hecke.defining_polynomial(K) == Hecke.Globals.Qx(BigInt.(record.coeffs))
            end
            @test all(r -> r.galois_label == "2T1" && r.degree == 2, rows)
            @test all(r -> -110 <= r.disc_sign * r.disc_abs <= 3300, rows)
            @test all(r -> r.class_group == "[2, 2]", rows)
            @test all(r -> 2 in r.ramps && 3 in r.ramps, rows)
        end

        @testset "Limit and empty results" begin
            rows = LMFDBLite.number_fields(db;
                galois_group = "2T1", limit = 1)
            @test length(rows) == 1

            @test isempty(LMFDBLite.number_fields(db;
                galois_group = "4T2", degree = 3, limit = 1))
            @test isempty(LMFDBLite.new_search(db, "nf_fields";
                galois_group = in(String[]), limit = 1))
        end

        @testset "Unsupported comparison" begin
            @test_throws ErrorException LMFDBLite.new_search(db, "nf_fields";
                galois_group = <("4T2"), limit = 1)
        end
    end

    @testset "Number field Galois status search" begin
        # Both Galois and non-Galois cubic fields occur in this small range.
        cases = [(true, "3T1"), (==(true), "3T1"),
                 (false, "3T2"), (==(false), "3T2")]
        @testset "Equality: $filter" for (filter, expected_label) in cases
            rows = LMFDBLite.new_search(db, "nf_fields";
                is_galois = filter, degree = 3,
                discriminant = in(-100:100), limit = 100)

            @test !isempty(rows)
            @test length(rows) < 100
            @test all(r -> r.is_galois === (expected_label == "3T1"), rows)
            @test all(r -> r.galois_label == expected_label && r.degree == 3, rows)
            @test all(r -> -100 <= r.disc_sign * r.disc_abs <= 100, rows)
        end

        @testset "Incompatible Galois groups" begin
            @test isempty(LMFDBLite.new_search(db, "nf_fields";
                is_galois = true, galois_group = "3T2", limit = 1))
            @test isempty(LMFDBLite.new_search(db, "nf_fields";
                is_galois = false, galois_group = "3T1", limit = 1))
        end

        @testset "Unsupported operators" begin
            @test_throws ErrorException LMFDBLite.new_search(db, "nf_fields";
                is_galois = <(true), limit = 1)
            @test_throws ErrorException LMFDBLite.new_search(db, "nf_fields";
                is_galois = in([true, false]), limit = 1)
        end
    end

    @testset "Number field root discriminant search" begin
        # Stored root discriminants may be rounded; use the stored value for equality.
        sample = only(LMFDBLite.new_search(db, "nf_fields";
            label = "2.2.5.1", limit = 2))
        # Check complete sets of quadratic fields in a small discriminant range.
        # The boundary at rd = 2 distinguishes strict from inclusive comparisons.
        cases = [
            (2, [-4]),
            (2.0, [-4]),
            (==(2.0), [-4]),
            (sample.rd, [5]),
            (<(2.0), [-3]),
            (<=(2.0), [-4, -3]),
            (>(2.0), [-8, -7, 5, 8]),
            (>=(2.0), [-8, -7, -4, 5, 8]),
            (<=(2.5), [-4, -3, 5]),
            (in([2.0, sample.rd]), [-4, 5]),
            (>=(2.0) & <=(2.5), [-4, 5]),
            (LMFDBLite.Or(<=(2.0), >(2.5)), [-8, -7, -4, -3, 8]),
            (<(1.0), Int[]),
        ]
        @testset "Filter: $filter" for (filter, expected_discriminants) in cases
            rows = LMFDBLite.new_search(db, "nf_fields";
                root_discriminant = filter, degree = 2, galois_group = "2T1",
                discriminant = in(-10:10), limit = 20)

            @test Set(Int(r.disc_sign * r.disc_abs) for r in rows) == Set(expected_discriminants)
            @test all(r -> r.rd ≈ sqrt(Float64(r.disc_abs)), rows)
        end

        @testset "Unsupported operators" begin
            @test_throws ErrorException LMFDBLite.new_search(db, "nf_fields";
                root_discriminant = LMFDBLite.includes([2.0]), limit = 1)
            @test_throws ErrorException LMFDBLite.new_search(db, "nf_fields";
                root_discriminant = >=(2.0) & LMFDBLite.includes([2.0]), limit = 1)
        end
    end

    @testset "Additional number field parameters" begin
        # Retrieve the complete reference set before applying each additional filter.
        reference = LMFDBLite.new_search(db, "nf_fields";
            degree = 2, discriminant = in(-50:50), limit = 100)
        @test 0 < length(reference) < 100
        labels(rows) = Set(r.label for r in rows)
        bounds = (; degree = 2, discriminant = in(-50:50), limit = 100)

        @testset "Label" begin
            expected = ["2.0.4.1", "2.2.12.1"]
            for filter in (expected[1], ==(expected[1]), in(expected))
                rows = LMFDBLite.new_search(db, "nf_fields"; label = filter)
                @test labels(rows) == Set(filter isa Base.Fix2{typeof(in)} ? expected : expected[1:1])
            end
            @test isempty(LMFDBLite.new_search(db, "nf_fields"; label = in(String[])))
            @test_throws ErrorException LMFDBLite.new_search(db, "nf_fields"; label = <(expected[1]))
        end

        @testset "Signature" begin
            for (criterion, r2) in [((2, 0), 0), ([0, 1], 1), (==((0, 1)), 1)]
                # Omit degree: the signature must constrain it itself.
                rows = LMFDBLite.new_search(db, "nf_fields";
                    signature = criterion, discriminant = in(-50:50), limit = 100)
                @test labels(rows) == labels(filter(r -> r.r2 == r2, reference))
            end
            @test isempty(LMFDBLite.new_search(db, "nf_fields";
                signature = (2, 0), degree = 3, limit = 1))
            for invalid in ((-1, 1), (0, 0), (2,), [1, 2, 3], (1.5, 1), "2,0")
                @test_throws ArgumentError LMFDBLite.new_search(db, "nf_fields"; signature = invalid)
            end
            for invalid in (<((2, 0)), in([(2, 0), (0, 1)]))
                @test_throws ErrorException LMFDBLite.new_search(db, "nf_fields"; signature = invalid)
            end
        end

        @testset "Integer invariant: $parameter" for parameter in
                (:class_number, :narrow_class_number, :relative_class_number, :index)
            cases = [
                (1, ==(1)), (==(2), ==(2)), (<(2), <(2)), (<=(2), <=(2)),
                (>(2), >(2)), (>=(2), >=(2)), (in([1, 3]), in([1, 3])),
                (in(1:2), in(1:2)), (in(1:2:5), in(1:2:5)),
                (in(2:1), _ -> false), (in(Int[]), _ -> false),
                (in(big(1):big(10)^30), >=(1)),
                (>=(2) & <=(3), x -> 2 <= x <= 3),
                (LMFDBLite.Or(==(1), >(3)), x -> x == 1 || x > 3),
            ]
            for (criterion, predicate) in cases
                rows = LMFDBLite.new_search(db, "nf_fields"; bounds..., parameter => criterion)
                expected = filter(reference) do r
                    value = getproperty(r, parameter)
                    !ismissing(value) && predicate(BigInt(value))
                end
                @test labels(rows) == labels(expected)
            end
            @test_throws ErrorException LMFDBLite.new_search(db, "nf_fields";
                parameter => LMFDBLite.includes([1]), limit = 1)
        end

        @testset "Narrow class group" begin
            for group in (Int[], [2], BigInt[3])
                for criterion in (group, ==(group))
                    rows = LMFDBLite.new_search(db, "nf_fields"; bounds..., narrow_class_group = criterion)
                    expected = filter(r -> r.narrow_class_group == group, reference)
                    @test !isempty(expected)
                    @test labels(rows) == labels(expected)
                end
            end
            # Q(sqrt(3)) has trivial class group but narrow class group C2.
            rows = LMFDBLite.new_search(db, "nf_fields";
                label = "2.2.12.1", class_group = Int[], narrow_class_group = [2],
                class_number = 1, narrow_class_number = 2)
            @test labels(rows) == Set(["2.2.12.1"])
            @test_throws ErrorException LMFDBLite.new_search(db, "nf_fields";
                narrow_class_group = LMFDBLite.includes([2]), limit = 1)
        end

        @testset "Real invariant: $parameter" for (parameter, column, boundary) in
                [(:galois_root_discriminant, :grd, 2), (:regulator, :regulator, 1)]
            cases = [
                (boundary, ==(boundary)), (==(Float64(boundary)), ==(boundary)),
                (<(boundary), <(boundary)), (<=(boundary), <=(boundary)),
                (>(boundary), >(boundary)), (>=(boundary), >=(boundary)),
                (in([boundary, boundary + 1]), in([boundary, boundary + 1])),
                (>=(boundary) & <=(boundary + 1), x -> boundary <= x <= boundary + 1),
            ]
            for (criterion, predicate) in cases
                rows = LMFDBLite.new_search(db, "nf_fields"; bounds..., parameter => criterion)
                expected = filter(r -> predicate(Float64(getproperty(r, column))), reference)
                @test labels(rows) == labels(expected)
            end
            @test_throws ErrorException LMFDBLite.new_search(db, "nf_fields";
                parameter => LMFDBLite.includes([1]), limit = 1)
        end

        @testset "Boolean invariant: $parameter" for (parameter, column) in
                [(:is_cyclic, :gal_is_cyclic), (:is_abelian, :gal_is_abelian),
                 (:is_solvable, :gal_is_solvable), (:is_cm, :cm),
                 (:is_minimal_sibling, :is_minimal_sibling)]
            # Include a known example of each value, even for nonsolvable groups.
            samples = [only(LMFDBLite.new_search(db, "nf_fields"; parameter => value, limit = 1))
                       for value in (true, false)]
            @test getproperty(samples[1], column) === true
            @test getproperty(samples[2], column) === false
            for value in (true, false), criterion in (value, ==(value))
                rows = LMFDBLite.new_search(db, "nf_fields";
                    label = in([r.label for r in samples]), parameter => criterion)
                @test labels(rows) == labels(filter(r -> getproperty(r, column) === value, samples))
                @test length(rows) == 1
            end
            @test_throws ErrorException LMFDBLite.new_search(db, "nf_fields";
                parameter => <(true), limit = 1)
            @test_throws ErrorException LMFDBLite.new_search(db, "nf_fields";
                parameter => in([true, false]), limit = 1)
        end

        @testset "Hecke conversion with new parameters" begin
            fields = LMFDBLite.number_fields(db;
                signature = (2, 0), class_number = 1, narrow_class_number = 2,
                narrow_class_group = [2], is_cm = false,
                discriminant = in(-50:50), limit = 100)
            @test fields isa Vector{Hecke.AbsSimpleNumField}
            @test !isempty(fields)
            expected = filter(r -> r.r2 == 0 && r.class_number == 1 && r.narrow_class_number == 2, reference)
            @test Set(Hecke.get_attribute(K, :lmfdb_label) for K in fields) == labels(expected)
        end
    end
end
