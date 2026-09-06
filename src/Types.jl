################################################################################
#
#  Mirror the SQL types
#
################################################################################

module SQL

abstract type ValueType end

struct smallint <: ValueType end

struct bigint <: ValueType end

struct text <: ValueType end

struct jsonb <: ValueType end

struct integer <: ValueType end

struct numeric <: ValueType end

struct boolean <: ValueType end

struct double <: ValueType end

struct real <: ValueType end

struct regproc <: ValueType end

struct character <: ValueType end

struct char <: ValueType end

struct oid <: ValueType end

struct name <: ValueType end

struct pg_node_tree <: ValueType end

struct aclitem <: ValueType end

struct anyarray <: ValueType end

struct xid <: ValueType end

struct int2vector <: ValueType end

struct oidvector <: ValueType end

struct timestampwithout <: ValueType end

struct pg_lsn <: ValueType end

struct bytea <: ValueType end

struct character_varying <: ValueType end

struct list{T} <: ValueType end

struct FieldName
  data::Symbol
end

struct TableLayout
  data::Dict{SQL.FieldName, SQL.ValueType}
end

struct Table
  name::Base.String
  layout::TableLayout
end

end

import .SQL

# Define the search condition type before Search.jl uses it in method signatures.
abstract type Condition end

################################################################################
#
#  Connection type
#
################################################################################

"""
    LMFDBConnection(; host, port, dbname, user, password)

Open an independently managed connection to an LMFDB PostgreSQL database.
Use `lmfdb()` for the lazily constructed, cached default connection.
"""
struct LMFDBConnection
  conn::FunSQL.SQLConnection{LibPQ.DBConnection}
  env#= properties of the connection =#
  table_names::Vector{String}
  table_layouts::Dict{String, SQL.TableLayout}

  function LMFDBConnection(; host = "devmirror.lmfdb.xyz",
                   port = "5432",
                   dbname = "lmfdb",
                   user = "lmfdb",
                   password = "lmfdb")
    raw = DBInterface.connect(LibPQ.Connection,
                                   """
                                   host=$host
                                   port=$port
                                   dbname=$dbname
                                   user=$user
                                   password=$password
                                   """)
    try
      # FunSQL cannot infer the dialect from LibPQ's DBInterface adapter type.
      catalog = FunSQL.reflect(raw; dialect = :postgresql)
      conn = FunSQL.SQLConnection(raw; catalog)
      tnames, tlayouts = query_meta_data(conn)
      return new(conn, (;host, port, dbname, user, password), tnames, tlayouts)
    catch
      DBInterface.close!(raw)
      rethrow()
    end
  end
end
