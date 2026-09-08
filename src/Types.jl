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

# libpq's keyword/value format requires quoting even for empty values. Escape
# backslashes and single quotes inside the quotes; Julia string escaping is a
# different format. Never include a connection value in an error message.
function _conninfo_value(value, name)
  s = string(value)
  occursin('\0', s) && throw(ArgumentError("connection parameter `$name` must not contain NUL"))
  return "'" * replace(s, '\\' => "\\\\", '\'' => "\\'") * "'"
end

function _connection_string(; host, port, dbname, user, password,
                            sslmode = nothing, sslrootcert = nothing,
                            sslcert = nothing, sslkey = nothing)
  parameters = (; host, port, dbname, user, password, sslmode, sslrootcert, sslcert, sslkey)
  return join(("$name=$(_conninfo_value(value, name))" for (name, value) in pairs(parameters)
               if value !== nothing), "\n")
end

"""
    LMFDBConnection(; host, port, dbname, user, password, schema = "public",
                     connect_timeout = 0, sslmode = nothing, sslrootcert = nothing,
                     sslcert = nothing, sslkey = nothing)

Open an independently managed connection to an LMFDB PostgreSQL database.
Connection values are passed literally, including spaces, quotes, and backslashes.
`connect_timeout` bounds initial connection establishment in seconds; zero means
no timeout. It does not set a query or `reset!` timeout. The TLS keywords are
libpq connection parameters; `nothing` leaves their environment/default settings
in effect. For example, use `sslmode = "verify-full"` with `sslrootcert` to specify
a trusted root certificate file.
Reflect tables in `schema` and use that schema for searches and column metadata,
independently of PostgreSQL's `search_path`. Typed table layouts are loaded and
cached on first use; unrelated tables do not need supported column types.
Open a new connection to refresh reflected tables and cached layouts after a
schema change. `reset!` only resets communication with the server.
Use `lmfdb()` for the lazily constructed, cached default connection.
"""
struct LMFDBConnection
  conn::FunSQL.SQLConnection{LibPQ.DBConnection}
  env#= properties of the connection =#
  schema::String
  table_names::Vector{String}
  table_layouts::Dict{Tuple{String, String}, SQL.TableLayout}
  table_layout_lock::ReentrantLock

  function LMFDBConnection(; host = "devmirror.lmfdb.xyz",
                   port = "5432",
                   dbname = "lmfdb",
                   user = "lmfdb",
                   password = "lmfdb",
                   schema::AbstractString = "public",
                   connect_timeout = 0,
                   sslmode = nothing, sslrootcert = nothing,
                   sslcert = nothing, sslkey = nothing)
    connect_timeout isa Real && isfinite(connect_timeout) && connect_timeout >= 0 ||
      throw(ArgumentError("`connect_timeout` must be a finite nonnegative number of seconds"))
    conninfo = _connection_string(; host, port, dbname, user, password,
                                 sslmode, sslrootcert, sslcert, sslkey)
    # LibPQ uses nonblocking connection setup: its Julia keyword enforces the
    # timeout, whereas a connect_timeout entry in conninfo would be ignored.
    raw = DBInterface.connect(LibPQ.Connection, conninfo; connect_timeout)
    try
      # FunSQL cannot infer the dialect from LibPQ's DBInterface adapter type.
      catalog = FunSQL.reflect(raw; schema, dialect = :postgresql)
      conn = FunSQL.SQLConnection(raw; catalog)
      # Reflection records names and qualified SQL tables without interpreting
      # column types. Use this same catalog for table discovery and searches.
      tnames = sort!(String.(collect(keys(catalog))))
      tlayouts = Dict{Tuple{String, String}, SQL.TableLayout}()
      return new(conn, (;host, port, dbname, user, password, connect_timeout,
                        sslmode, sslrootcert, sslcert, sslkey), String(schema),
                 tnames, tlayouts, ReentrantLock())
    catch
      DBInterface.close!(raw)
      rethrow()
    end
  end
end

function Base.show(io::IO, conn::LMFDBConnection)
  print(io, "LMFDB database connection to ", conn.env.host, ":", conn.env.port)
end

function Base.show(io::IO, ::MIME"text/plain", conn::LMFDBConnection)
  println(io, "Connection to the LMFDB database")
  println(io, "  host: ", conn.env.host)
  print(io, "  port: ", conn.env.port)
end
