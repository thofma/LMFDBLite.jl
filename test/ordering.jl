import FunSQL

function ordering_layout(table)
    layout = Dict{LMFDBLite.SQL.FieldName, LMFDBLite.SQL.ValueType}(
        LMFDBLite.SQL.FieldName(:id) => LMFDBLite.SQL.bigint())
    for spec in values(LMFDBLite._search_parameter_definitions(table))
        columns, types = LMFDBLite._parameter_columns_and_types(spec)
        for (column, type) in zip(columns, types)
            layout[LMFDBLite.SQL.FieldName(column)] = type()
        end
    end
    return layout
end

function ordering_sql(table, order_by; layout = ordering_layout(table))
    definitions = LMFDBLite._search_parameter_definitions(table)
    terms = LMFDBLite._order_terms(table, definitions, layout, order_by)
    query = FunSQL.From(FunSQL.SQLTable(Symbol(table); columns = [k.data for k in keys(layout)]))
    isempty(terms) || (query = query |> FunSQL.Order(terms...))
    return string(FunSQL.render(query; dialect = :postgresql))
end

@testset "Explicit ordering without a database" begin
    for table in ("nf_fields", "ec_curvedata", "ec_nfcurves", "lat_lattices_new", "lat_genera")
        for unordered in (nothing, (), [])
            @test !occursin("ORDER BY", ordering_sql(table, unordered))
        end
        # Public labels map to lmfdb_label for rational curves and label elsewhere.
        column = table == "ec_curvedata" ? "lmfdb_label" : "label"
        sql = ordering_sql(table, :label)
        order = split(sql, "ORDER BY")[2]
        @test occursin("\"$column\" ASC NULLS LAST", order)
        @test endswith(strip(order), "\"id\" ASC NULLS LAST")
        @test ordering_sql(table, :label) == ordering_sql(table, :label => :asc) ==
              ordering_sql(table, (:label,)) == ordering_sql(table, [:label => :asc])
        @test occursin("DESC NULLS LAST", ordering_sql(table, :label => :desc))
        @test_throws ArgumentError ordering_sql(table, :unknown)
        @test_throws ArgumentError ordering_sql(table, (:label, :label => :desc))
        @test_throws ArgumentError ordering_sql(table, :signature)
    end
    for invalid in ("degree", 1, true, missing, (degree = :asc,), Set([:degree]),
                    :degree => 1, :degree => "desc", :degree => :descending,
                    :degree => missing, "degree" => :asc, (:degree, "label"),
                    (:degree, :asc), (:degree, :label => :invalid))
        @test_throws ArgumentError ordering_sql("nf_fields", invalid)
    end
    @test_throws ArgumentError ordering_sql("ec_curvedata", :lmfdb_label)
    @test_throws ArgumentError ordering_sql("lat_genera", (:det, :determinant))
    for (table, unsupported) in (("nf_fields", :class_group), ("nf_fields", :ramified),
                                 ("ec_curvedata", :j_invariant), ("lat_genera", :mass),
                                 ("ec_nfcurves", :torsion_structure), ("lat_lattices_new", :gram_matrix))
        @test_throws ArgumentError ordering_sql(table, unsupported)
    end
    for (table, absolute, sign) in (("nf_fields", "disc_abs", "disc_sign"),
                                     ("ec_curvedata", "absD", "signD"))
        order = split(ordering_sql(table, :discriminant => :desc), "ORDER BY")[2]
        @test occursin("\"$absolute\"", order)
        @test occursin("\"$sign\"", order)
        @test occursin(" * ", order)
        @test occursin("DESC NULLS LAST", order)
    end
    for (table, parameter, column) in (("ec_curvedata", :torsion_order, "torsion"),
                                      ("ec_nfcurves", :conductor_norm, "conductor_norm"),
                                      ("lat_lattices_new", :disc, "disc"),
                                      ("lat_genera", :det, "det"),
                                      ("nf_fields", :is_cm, "cm"),
                                      ("nf_fields", :absolute_discriminant, "disc_abs"))
        order = split(ordering_sql(table, parameter), "ORDER BY")[2]
        @test occursin("\"$column\" ASC NULLS LAST", order)
    end
    layout = ordering_layout("nf_fields")
    delete!(layout, LMFDBLite.SQL.FieldName(:disc_sign))
    @test_throws ErrorException ordering_sql("nf_fields", :discriminant; layout)
    layout = ordering_layout("nf_fields")
    layout[LMFDBLite.SQL.FieldName(:degree)] = LMFDBLite.SQL.text()
    @test_throws ErrorException ordering_sql("nf_fields", :degree; layout)
    for type in (nothing, LMFDBLite.SQL.text())
        layout = ordering_layout("nf_fields")
        if type === nothing
            delete!(layout, LMFDBLite.SQL.FieldName(:id))
        else
            layout[LMFDBLite.SQL.FieldName(:id)] = type
        end
        @test_throws ArgumentError ordering_sql("nf_fields", :label; layout)
        @test !occursin("ORDER BY", ordering_sql("nf_fields", nothing; layout))
    end
end
