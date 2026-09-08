# Exercise each public scalar integer parameter, including aliases and parameters
# with multiple physical columns. The helpers in composition.jl need no database.
function integer_range_parameters()
    return [(table, parameter, spec)
            for table in ("nf_fields", "ec_curvedata", "ec_nfcurves", "lat_lattices_new", "lat_genera")
            for (parameter, spec) in LMFDBLite._search_parameter_definitions(table)
            if spec[1] === BigInt && in in spec[5]]
end

function test_integer_ranges(convert_value)
    @testset "Integer range membership: $(typeof(convert_value(0)))" begin
        lo, hi, one, two = convert_value.((-4, 5, 1, 2))
        ranges = (lo:hi, lo:one:hi, hi:-one:lo, hi:hi, hi:lo, lo:-one:hi)
        stepped = (lo:two:hi, hi:-two:lo, hi:two:hi, hi:two:lo)
        for (table, parameter, spec) in integer_range_parameters()
            columns, _ = LMFDBLite._parameter_columns_and_types(spec)
            signed = length(columns) == 2
            reference = BigInt[x for x in -8:8 if !signed || x != 0]
            row(x) = NamedTuple{columns}(signed ? (abs(x), sign(x)) : (x,))
            for r in ranges
                # Materializing these small reference ranges provides an
                # independent check of their membership and empty-range semantics.
                values = BigInt.(collect(r))
                condition = composition_condition(table, parameter, in(r))
                @test filter(x -> evaluate_number_field_condition(condition, row(x)), reference) ==
                      filter(x -> x in values, reference)
                sql = composition_sql(table, parameter, condition)
                @test occursin(isempty(values) ? "WHERE FALSE" : "BETWEEN", sql)
            end

            # Explicit vectors preserve the gaps in stepped membership.
            values = collect(lo:two:hi)
            condition = composition_condition(table, parameter, in(values))
            @test filter(x -> evaluate_number_field_condition(condition, row(x)), reference) ==
                  filter(x -> x in BigInt.(values), reference)

            for r in stepped
                bad = in(r)
                for criterion in (bad, allof(in(convert_value.(Int[])), bad),
                                  anyof(in(lo:hi), bad))
                    @test_throws ArgumentError composition_condition(table, parameter, criterion)
                end
            end
        end
    end
end

function test_large_integer_ranges(convert_value, magnitude)
    @testset "Compact integer ranges: $(typeof(convert_value(0)))" begin
        lo, hi, one = convert_value.((-magnitude, magnitude, 1))
        for (table, parameter, _) in integer_range_parameters()
            canonical = composition_condition(table, parameter, in(lo:hi))
            expected_sql = composition_sql(table, parameter, canonical)
            for r in (lo:hi, lo:one:hi, hi:-one:lo)
                condition = composition_condition(table, parameter, in(r))
                sql = composition_sql(table, parameter, condition)
                @test sql == expected_sql
                @test sizeof(sql) < 800
                @test discriminant_node_count(condition) <= 7
                @test occursin("BETWEEN", sql)
                @test !occursin(" IN ", sql)
            end
        end
    end
end

@testset "Integer ranges across all tables" begin
    for T in (Int, Int32, BigInt)
        test_integer_ranges(T)
    end
    test_large_integer_ranges(Int, 10^9)
    test_large_integer_ranges(BigInt, big(10)^30)

    @testset "Stepped-range error and migration example" begin
        err = try
            composition_condition("nf_fields", :class_number, in(1:2:9))
        catch e
            e
        end
        @test err isa ArgumentError
        @test occursin("`class_number`", sprint(showerror, err))
        @test occursin("explicit vector", sprint(showerror, err))
        explicit = composition_condition("nf_fields", :class_number, in([1, 3, 5, 7, 9]))
        collected = composition_condition("nf_fields", :class_number, in(collect(1:2:9)))
        @test composition_sql("nf_fields", :class_number, explicit) ==
              composition_sql("nf_fields", :class_number, collected)
    end
end

function test_live_integer_ranges(conn, table, parameter, column, reference)
    @testset "Integer ranges against live records: $table/$parameter" begin
        label(r) = table == "ec_curvedata" ? r.lmfdb_label : r.label
        labels(rows) = Set(label(r) for r in rows)
        pool = label.(reference)
        for r in (1:1:2, 2:-1:1, Hecke.ZZ(1):Hecke.ZZ(2),
                  Hecke.ZZ(2):Hecke.ZZ(-1):Hecke.ZZ(1), 2:1, 1:-1:2)
            rows = LMFDBLite.search(conn, table; label = in(pool), parameter => in(r))
            values = BigInt.(collect(r))
            @test labels(rows) == labels(filter(reference) do record
                value = getproperty(record, column)
                !ismissing(value) && BigInt(value) in values
            end)
        end
        @test_throws ArgumentError LMFDBLite.search(conn, table;
            label = in(pool), parameter => anyof(==(1), in(1:2:9)), limit = 1)
    end
end
