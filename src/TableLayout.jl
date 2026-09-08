function get_type(name::String)
  if name == "bigint"
    return SQL.bigint()
  elseif name == "jsonb"
    return SQL.jsonb()
  elseif name == "text"
    return SQL.text()
  elseif name == "smallint"
    return SQL.smallint()
  elseif name == "integer"
    return SQL.integer()
  elseif name == "numeric"
    return SQL.numeric()
  elseif name == "boolean"
    return SQL.boolean()
  elseif name == "double precision"
    return SQL.double()
  elseif name == "real"
    return SQL.real()
  elseif name == "regproc"
    return SQL.regproc()
  elseif name == "character"
    return SQL.character()
  elseif name == "oid"
    return SQL.oid()
  elseif name == "name"
    return SQL.name()
  elseif name == "pg_node_tree"
    return SQL.pg_node_tree()
  elseif name == "int2vector"
    return SQL.int2vector()
  elseif name == "oidvector"
    return SQL.oidvector()
  elseif name == "pg_lsn"
    return SQL.pg_lsn()
  elseif name == "bytea"
    return SQL.bytea()
  elseif name == "character varying"
    return SQL.character_varying()
  elseif name == "text[]"
    return SQL.list{SQL.text}()
  elseif name == "integer[]"
    return SQL.list{SQL.integer}()
  elseif name == "numeric[]"
    return SQL.list{SQL.numeric}()
  elseif name == "double precision[]"
    return SQL.list{SQL.double}()
  elseif name == "smallint[]"
    return SQL.list{SQL.smallint}()
  elseif name == "bigint[]"
    return SQL.list{SQL.bigint}()
  elseif name == "real[]"
    return SQL.list{SQL.real}()
  elseif name == "aclitem[]"
    return SQL.list{SQL.aclitem}()
  elseif name == "oid[]"
    return SQL.list{SQL.oid}()
  elseif name == "\"char\"[]"
    return SQL.list{SQL.char}()
  elseif name == "anyarray"
    return SQL.list{SQL.anyarray}()
  elseif name == "xid"
    return SQL.xid()
  elseif name == "timestamp without time zone"
    return SQL.timestampwithout()
  else
    error("Type of name \"$(name)\" not added yet")
  end
end

function SQL.TableLayout(v::Vector)
  D = Dict{SQL.FieldName, SQL.ValueType}()
  for entry in v
    D[SQL.FieldName(Symbol(entry.column_name))] = get_type(entry.regtype)
  end
  return SQL.TableLayout(D)
end

function query_table_layout(conn::LMFDBConnection, tname::String)
  # Match the schema-qualified table reflected by FunSQL. Looking up types by
  # OID avoids resolving unqualified type names through the session search_path.
  # Omit type modifiers: e.g. numeric(20, 0) still has the SQL type numeric.
  # Only the requested table is converted, so unknown types elsewhere cannot
  # prevent a connection or a search on a supported table.
  q = raw"""
      SELECT a.attname AS column_name,
             pg_catalog.format_type(a.atttypid, NULL) AS regtype
      FROM pg_catalog.pg_namespace AS n
      JOIN pg_catalog.pg_class AS c ON c.relnamespace = n.oid
      JOIN pg_catalog.pg_attribute AS a ON a.attrelid = c.oid
      WHERE n.nspname = $1 AND c.relname = $2
        AND a.attnum > 0 AND NOT a.attisdropped
      ORDER BY a.attnum
      """
  result = DBInterface.execute(conn.conn.raw, q, [conn.schema, tname])
  try
    return SQL.TableLayout(rowtable(result))
  finally
    close(result)
  end
end
