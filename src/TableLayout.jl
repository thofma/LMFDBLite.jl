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
    return SQL.regproc()
  elseif name == "oid"
    return SQL.oid()
  elseif name == "name"
    return SQL.name()
  elseif name == "pg_node_tree"
    return SQL.pg_node_tree()
  elseif name == "int2vector"
    return SQL.int2vector()
  elseif name == "oidvector"
    return SQL.int2vector()
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
