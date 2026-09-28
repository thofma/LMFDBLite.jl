function test_live_ordering(conn)
    @testset "Ordering live records and Hecke objects" begin
        cases = (
            ("nf_fields", :discriminant,
             (; label = in(["1.1.1.1", "2.0.3.1", "2.0.4.1", "2.2.5.1", "2.2.8.1"])),
             r -> BigInt(r.disc_abs) * BigInt(r.disc_sign), LMFDBLite.number_fields),
            ("ec_curvedata", :conductor, (; conductor = in([11, 37])),
             r -> BigInt(r.conductor), LMFDBLite.elliptic_curves),
            ("ec_nfcurves", :conductor_norm,
             (; label = in(["2.2.5.1-31.1-a1", "2.2.5.1-599.1-b1", "3.1.23.1-89.1-A1"])),
             r -> BigInt(r.conductor_norm), LMFDBLite.elliptic_curves_over_number_fields),
            ("lat_lattices_new", :discriminant, (; rank = 1),
             r -> BigInt(r.disc), LMFDBLite.integer_lattices),
            ("lat_genera", :determinant, (; rank = 1),
             r -> BigInt(r.det), Hecke.integer_genera),
        )
        for (table, parameter, selection, value, convert_records) in cases
            @testset "$table" begin
                # This initial subset is arbitrary; all subsequent queries are
                # restricted to it and compared with an independent Julia sort.
                reference = LMFDBLite.search(conn, table; selection..., limit = 5)
                @test length(reference) >= 2
                label(r) = table == "ec_curvedata" ? r.lmfdb_label : r.label
                bounds = (; label = in(label.(reference)))
                for direction in (:asc, :desc)
                    factor = direction == :asc ? 1 : -1
                    expected = sort(reference; by = r -> (factor * value(r), r.id))
                    order_by = parameter => direction
                    rows = LMFDBLite.search(conn, table; bounds..., order_by, limit = 2)
                    @test getproperty.(rows, :id) == getproperty.(expected[1:2], :id)
                    objects = convert_records(conn; bounds..., order_by, limit = 2)
                    @test Hecke.get_attribute.(objects, :lmfdb_label) == label.(expected[1:2])
                    @test LMFDBLite.count(conn, table; bounds..., order_by, limit = 2) == 2
                end
            end
        end
        reference = LMFDBLite.search(conn, "ec_curvedata"; conductor = in([11, 37]))
        expected = sort(reference; by = r -> (r.conductor, -r.rank, r.id))
        curves = LMFDBLite.elliptic_curves(conn; conductor = in([11, 37]),
            order_by = (:conductor => :asc, :rank => :desc), limit = 3)
        @test Hecke.get_attribute.(curves, :lmfdb_label) == getproperty.(expected[1:3], :lmfdb_label)
    end
end
