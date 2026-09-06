module LMFDBLite

using LibPQ
using Tables
using DBInterface
using FunSQL
using LibPQ.Decimals

import FunSQL: Where, Get, From, Fun, Select, Order, SQLTable, Limit, Agg, Group

DBInterface.connect(::Type{LibPQ.Connection}, args...; kws...) =
    LibPQ.Connection(args...; kws...)

DBInterface.prepare(conn::LibPQ.Connection, args...; kws...) =
    LibPQ.prepare(conn, args...; kws...)

DBInterface.execute(conn::Union{LibPQ.Connection, LibPQ.Statement}, args...; kws...) =
    LibPQ.execute(conn, args...; kws...)

include("Types.jl")
include("TableLayout.jl")
include("Search.jl")
include("Conditions.jl")

DBInterface.execute(conn::LMFDBConnection, args...; kw...) =
    DBInterface.execute(conn.conn, args...; kw...)

function query_table_names(conn::FunSQL.SQLConnection)
  q = From(SQLTable(:pg_tables; columns = [:tablename])) |>
      Select(:tablename) |>
      Order(Get.tablename)
  res = DBInterface.execute(conn, q)
  return getproperty.(rowtable(res), :tablename)
end

function query_meta_data(conn::FunSQL.SQLConnection{LibPQ.Connection})
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

using .LMFDBLite
