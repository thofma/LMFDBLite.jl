@testset "Parameter consistency checks without a database" begin
    SQL = LMFDBLite.SQL
    parameters = LMFDBLite._new_number_field_parameters()
    spec = parameters[:narrow_class_group]
    # The user-facing types agree even though the PostgreSQL representations differ.
    @test parameters[:class_group][1] === spec[1] === Vector{BigInt}

    layout = Dict{SQL.FieldName, SQL.ValueType}(
        SQL.FieldName(:narrow_class_group) => SQL.list{SQL.bigint}())
    @test isnothing(LMFDBLite._check_parameter_schema(layout, "nf_fields", :narrow_class_group, spec))

    # Simulate a database type change without altering any actual database.
    layout[SQL.FieldName(:narrow_class_group)] = SQL.jsonb()
    err = try
        LMFDBLite._check_parameter_schema(layout, "nf_fields", :narrow_class_group, spec)
    catch e
        e
    end
    @test err isa ErrorException
    message = sprint(showerror, err)
    @test occursin("nf_fields.narrow_class_group", message)
    @test occursin("jsonb", message)
    @test occursin("bigint", message)

    delete!(layout, SQL.FieldName(:narrow_class_group))
    @test_throws r"requires missing column `nf_fields.narrow_class_group`" LMFDBLite._check_parameter_schema(
        layout, "nf_fields", :narrow_class_group, spec)

    @testset "Composite parameter: $parameter" for (parameter, columns, types) in
            [(:signature, (:degree, :r2), (SQL.smallint, SQL.smallint)),
             (:discriminant, (:disc_abs, :disc_sign), (SQL.numeric, SQL.smallint))]
        layout = Dict{SQL.FieldName, SQL.ValueType}(
            SQL.FieldName(column) => T() for (column, T) in zip(columns, types))
        @test isnothing(LMFDBLite._check_parameter_schema(layout, "nf_fields", parameter, parameters[parameter]))
        delete!(layout, SQL.FieldName(columns[2]))
        @test_throws ErrorException LMFDBLite._check_parameter_schema(layout, "nf_fields", parameter, parameters[parameter])
        layout[SQL.FieldName(columns[2])] = SQL.text()
        @test_throws ErrorException LMFDBLite._check_parameter_schema(layout, "nf_fields", parameter, parameters[parameter])
    end

    @testset "Malformed declarations" begin
        for (types, columns) in [(Int, :degree), (SQL.smallint, missing),
                                ((SQL.smallint,), (:degree, :r2))]
            invalid = (BigInt, types, columns, identity, Any[==])
            @test_throws AssertionError LMFDBLite._parameter_columns_and_types(invalid)
        end
    end

    @testset "Undeclared columns in generated conditions" begin
        valid = LMFDBLite.create_cond(:degree, ==(2)) & LMFDBLite.create_cond(:r2, ==(0))
        @test isnothing(LMFDBLite._assert_parameter_columns(valid, (:degree, :r2), :signature))
        invalid = LMFDBLite.create_cond(:class_number, ==(1))
        for condition in (invalid, valid & invalid, valid | invalid)
            @test_throws AssertionError LMFDBLite._assert_parameter_columns(condition, (:degree, :r2), :signature)
        end
    end
end

function test_number_field_parameter_consistency(db)
    @testset "Number field parameter declarations match PostgreSQL" begin
        @test isnothing(LMFDBLite.check_number_field_parameters(db))
        layout = LMFDBLite.table_layout(db, "nf_fields")
        @testset "$parameter" for (parameter, spec) in LMFDBLite._new_number_field_parameters()
            @test isnothing(LMFDBLite._check_parameter_schema(layout, "nf_fields", parameter, spec))
        end

        # Change only the cached metadata to verify that new_search enforces the check.
        # Always restore it before running the remaining live queries.
        column = LMFDBLite.SQL.FieldName(:narrow_class_group)
        original = layout[column]
        try
            layout[column] = LMFDBLite.SQL.jsonb()
            @test_throws ErrorException LMFDBLite.new_search(db, "nf_fields";
                narrow_class_group = [2], limit = 1)
            delete!(layout, column)
            @test_throws ErrorException LMFDBLite.new_search(db, "nf_fields";
                narrow_class_group = [2], limit = 1)
        finally
            layout[column] = original
        end
        @test isnothing(LMFDBLite.check_number_field_parameters(db))
        @test_throws ArgumentError LMFDBLite.new_search(db, "nf_fields";
            unknown_parameter = 1, limit = 1)
        # Unsupported tables must not silently receive number field definitions.
        @test_throws ArgumentError LMFDBLite.new_search(db, "lat_lattices"; limit = 1)
    end
end
