module LMFDBLite

export lmfdb, includes, reset!, allof, anyof

using LibPQ
using Tables
using DBInterface
using FunSQL
using LibPQ.Decimals

import FunSQL: Where, Get, From, Fun, Select, Order, SQLTable, Limit, Agg, Group

include("Types.jl")
include("TableLayout.jl")
include("Search.jl")
include("SearchParameters/Quadratic.jl")
include("SearchParameters/Lattice.jl")
include("SearchParameters/Genus.jl")
include("SearchParameters/NumberField.jl")
include("SearchParameters/EllipticCurve.jl")
include("Conditions.jl")
include("Lattice.jl")
include("Genus.jl")
include("NumberField.jl")
include("EllipticCurve.jl")

const _lmfdb_lock = ReentrantLock()
const _lmfdb_cache = Ref{Union{Nothing, LMFDBConnection}}(nothing)

Base.isopen(conn::LMFDBConnection) = isopen(conn.conn.raw.conn)

"""
    reset!(conn::LMFDBConnection; throw_error = true)

Reset communication with the LMFDB PostgreSQL server using the connection's
original parameters. A connection that has been explicitly closed cannot be
reset.
"""
function LibPQ.reset!(conn::LMFDBConnection; throw_error::Bool = true)
  LibPQ.reset!(conn.conn.raw.conn; throw_error)
  return nothing
end

DBInterface.execute(conn::LMFDBConnection, args...; kw...) =
  DBInterface.execute(conn.conn, args...; kw...)

function DBInterface.close!(conn::LMFDBConnection)
  lock(_lmfdb_lock) do
    try
      DBInterface.close!(conn.conn)
    finally
      if _lmfdb_cache[] === conn
        _lmfdb_cache[] = nothing
      end
    end
  end
  return nothing
end

"""
    lmfdb() -> LMFDBConnection

Return the cached connection to the default LMFDB database. The connection is
constructed lazily on the first call. Closing it with `DBInterface.close!`
invalidates the cache, so the next call constructs a new connection.
"""
function lmfdb()::LMFDBConnection
  return lock(_lmfdb_lock) do
    conn = _lmfdb_cache[]
    if conn === nothing || !isopen(conn)
      conn = LMFDBConnection()
      _lmfdb_cache[] = conn
    end
    return conn
  end
end

function _close_cached_lmfdb()
  lock(_lmfdb_lock) do
    conn = _lmfdb_cache[]
    if conn !== nothing
      DBInterface.close!(conn.conn)
      _lmfdb_cache[] = nothing
    end
  end
  return nothing
end

function __init__()
  atexit(_close_cached_lmfdb)
end

function query_table_names(conn::FunSQL.SQLConnection)
  q = From(SQLTable(:pg_tables; columns = [:tablename])) |>
      Select(:tablename) |>
      Order(Get.tablename)
  res = DBInterface.execute(conn, q)
  return getproperty.(rowtable(res), :tablename)
end

function query_meta_data(conn::FunSQL.SQLConnection{LibPQ.DBConnection})
  tnames = query_table_names(conn)

  q =  From(SQLTable(qualifiers = [:information_schema], :columns, columns = [:table_name :column_name :udt_name])) |>
        Select(:table_name, :column_name, Fun(:regtype, Get(:udt_name)))
  res = rowtable(DBInterface.execute(conn, q))

  D = Dict{String, SQL.TableLayout}()
  for t in tnames
    D[t] = SQL.TableLayout(filter(r -> r.table_name == t, res))
  end
  return tnames, D
end

end # module LMFDBLite
