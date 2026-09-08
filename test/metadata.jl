@testset "PostgreSQL type mappings" begin
    SQL = LMFDBLite.SQL
    for (name, expected) in [("character", SQL.character), ("regproc", SQL.regproc),
                             ("oidvector", SQL.oidvector), ("int2vector", SQL.int2vector)]
        @test LMFDBLite.get_type(name) isa expected
    end
    @test_throws r"Type of name \"date\" not added yet" LMFDBLite.get_type("date")
end

function test_lazy_metadata(conn)
    @testset "Lazy metadata on the LMFDB connection" begin
        @test isempty(conn.table_layouts)
        @test conn.schema == get(ENV, "LMFDB_SCHEMA", "public")
        layout = LMFDBLite.table_layout(conn, "nf_fields")
        @test layout[LMFDBLite.SQL.FieldName(:degree)] isa LMFDBLite.SQL.smallint
        @test Set(keys(conn.table_layouts)) == Set([(conn.schema, "nf_fields")])
        @test LMFDBLite.table_layout(conn, "nf_fields") === layout
        @test isnothing(LMFDBLite.check_table_column_name(conn, "nf_fields", :degree))
        @test_throws ArgumentError LMFDBLite.check_table_column_name(
            conn, "nf_fields", :nonexistent_column)
    end
end
