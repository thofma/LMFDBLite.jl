# Design
#
# - the search setup will promote any integer to BigInt

################################################################################
#
#  Search parameter handling
#
################################################################################

struct And
  a
  b
end

Base.:&(a::Function, b::Function) = And(a, b)

struct Or
  a
  b
end

################################################################################
#
#  Formalizatin of restrictions
#
################################################################################

function issuperset(x, y)
  return issubset(y, x)
end

issuperset(x) = Base.Fix2(issuperset, x)

includes = issuperset

#            - ``$contains`` -- for json columns, the given value should be a subset of the column.
#            - ``$notcontains`` -- for json columns, the column must not contain any entry of the given value (which should be iterable)
#            - ``$containedin`` -- for json columns, the column should be a subset of the given list
#            - ``$overlaps`` -- the column should overlap the given array
#            - ``$exists`` -- if True, require not null; if False, require null.
#            - ``$startswith`` -- for text columns, matches strings that start with the given string.
#            - ``$like`` -- for text columns, matches strings according to the LIKE operand in SQL.
#            - ``$ilike`` -- for text columns, matches strings according to the ILIKE, the case-insensitive version of LIKE in PostgreSQL.
#            - ``$regex`` -- for text columns, matches the given regex expression supported by PostgresSQL
#            - ``$raw`` -- a string to be inserted as SQL after filtering against SQL injection

for ex in [(:(Base.Fix2{typeof(==)}),         :("="),           :(_prepare_for_lookup(t.x))),
           (:(Base.Fix2{typeof(<=)}),         :("<="),          :(_prepare_for_lookup(t.x))),
           (:(Base.Fix2{typeof(<)}) ,         :("<"),           :(_prepare_for_lookup(t.x))),
           (:(Base.Fix2{typeof(>=)}),         :(">="),          :(_prepare_for_lookup(t.x))),
           (:(Base.Fix2{typeof(>)}) ,         :(">"),           :(_prepare_for_lookup(t.x))),
           (:(Base.Fix2{typeof(!=)}),         :("!="),          :(_prepare_for_lookup(t.x))),
           (:(Base.Fix2{typeof(issubset)}),   :(" <@"),         :(_prepare_for_lookup(t.x))),
           (:(Base.Fix2{typeof(issuperset)}), :(" @>"),         :(_prepare_for_lookup(t.x))),
           (:(Base.Fix2{typeof(in)}),         :("in"),          :(t.x...)),
           (:(Base.Fix2{typeof(in), T} where {T <: OrdinalRange{BigInt}}),         :("between"),          :((first(t.x), last(t.x))...)),
           (:(Base.Fix2{typeof(startswith)}), :("starts_with"), :(_prepare_for_lookup(t.x))), # David uses "like"?
           (:(Base.Fix2{typeof(contains)}),   :("in"),          :(_prepare_for_lookup(t.x)))
          ]
  @eval function create_fun(s::Symbol, t::$(ex[1]))
    if typeof(t) <: Base.Fix2{typeof(in), T} where {T <: OrdinalRange{BigInt}}
      if step(t.x) == -1
        return Fun.$(ex[2])(Get(s), reverse(($(ex[3]),))...)
      else
        @assert step(t.x) == 1
        return Fun.$(ex[2])(Get(s), $(ex[3]))
      end
    end
    if typeof(t) <: Base.Fix2{typeof(contains), String}
      return Fun."in"($(ex[3]), Get(s))
    end

    return Fun.$(ex[2])(Get(s), $(ex[3]))
  end
end

function create_fun(s::Symbol, c::Base.ComposedFunction{typeof(!)})
  return Fun.not(create_fun(s, c.inner))
end

function create_fun(s::Symbol, c::And)
  return Fun.and(create_fun(s, c.a), create_fun(s, c.b))
end

function create_fun(s::Symbol, c::Or)
  return Fun.or(create_fun(s, c.a), create_fun(s, c.b))
end

################################################################################
#
#  Conversions
#
################################################################################

# a rational number is stored as a []numeric
_prepare_for_lookup(x) = x

function _prepare_for_lookup(x::Rational{<:Integer})
  return _stringify_list([Decimal(BigInt(numerator(x))), Decimal((BigInt(denominator(x))))])
end

function _prepare_for_lookup(x::Vector{Int})
  return _stringify_list(Decimal.(x))
end

# FunSQL does not like Vector, so we turn it into a list by hand
function _stringify_list(a::Vector)
  return "{" * join(a, ",") * "}"
end

################################################################################
#
#  Search
#
################################################################################

function check_table_name(conn::LMFDBConnection, tname::String)
  if !(tname in conn.table_names)
    throw(ArgumentError("Table with name $(tname) does not exist; see `tables_names`"))
  end
end

function check_table_column_name(conn::LMFDBConnection, tname::String, column::Symbol)
  layout = conn.table_layouts[tname].data # Dict{FieldName, SQL.ValueType}
  if !(LMFDBLite.SQL.FieldName(column) in keys(layout))
    throw(ArgumentError("Table $(tname) does not have a column named \"$(column)\". See `table_layout`."))
  end
end

function table_layout(conn::LMFDBConnection, tname::String)
  check_table_name(conn, tname)
  return conn.table_layouts[tname].data
end

# A parameter can map to one column or to a tuple of columns (e.g. signature).
function _parameter_columns_and_types(spec)
  _, sqltypes, columns, _, _ = spec
  columns = columns isa Symbol ? (columns,) : columns
  sqltypes = sqltypes isa Type ? (sqltypes,) : sqltypes
  @assert columns isa Tuple && !isempty(columns) && all(c -> c isa Symbol, columns) "search parameters must declare their database columns"
  @assert sqltypes isa Tuple && length(sqltypes) == length(columns) "each declared column must have a PostgreSQL type"
  @assert all(T -> T isa Type && T <: SQL.ValueType, sqltypes) "expected PostgreSQL types, not search parameter types"
  return columns, sqltypes
end

function _check_parameter_schema(layout, tname, parameter, spec)
  columns, sqltypes = _parameter_columns_and_types(spec)
  for (column, expected) in zip(columns, sqltypes)
    actual = get(layout, SQL.FieldName(column), nothing)
    if actual === nothing
      error("search parameter `$parameter` requires missing column `$tname.$column` (expected $expected)")
    elseif typeof(actual) !== expected
      error("search parameter `$parameter`: column `$tname.$column` has type $(typeof(actual)); expected $expected")
    end
  end
  return nothing
end

function _search_parameters(tname::String)
  if tname == "nf_fields"
    return _number_field_parameters()
  elseif tname == "lat_lattices_new"
    return _lattice_parameters()
  elseif tname == "lat_genera"
    return _genus_parameters()
  elseif tname == "ec_curvedata"
    return _elliptic_curve_parameters()
  end
  throw(ArgumentError("search has no parameter definitions for table `$tname`"))
end

"""
    check_search_parameters(conn, table)

Check all parameter declarations for `table` against the PostgreSQL metadata
collected when `conn` was opened. Return `nothing` on success, or report the
parameter, column, and expected type on a mismatch. No additional queries are made.
"""
function check_search_parameters(conn::LMFDBConnection, tname::String)
  layout = table_layout(conn, tname)
  for (parameter, spec) in _search_parameters(tname)
    _check_parameter_schema(layout, tname, parameter, spec)
  end
  return nothing
end

"""
    check_number_field_parameters(conn)

Check all number field declarations using `check_search_parameters(conn, "nf_fields")`.
"""
check_number_field_parameters(conn::LMFDBConnection) = check_search_parameters(conn, "nf_fields")

function _search_query(conn::LMFDBConnection, tname::String; limit = Inf, kw...)
  layout = table_layout(conn, tname)
  parameters = _search_parameters(tname)
  conds = Condition[]
  for (parameter, value) in kw
    haskey(parameters, parameter) || throw(ArgumentError("unknown search parameter `$parameter` for table `$tname`"))
    spec = parameters[parameter]
    _check_parameter_schema(layout, tname, parameter, spec)
    _, _, column, builder, allowed = spec
    cond = builder(column, value, parameter, allowed)
    columns, _ = _parameter_columns_and_types(spec)
    _assert_parameter_columns(cond, columns, parameter)
    push!(conds, cond)
  end
  q = From(tname) |> _create_where(conds)
  if limit != Inf
    q = q |> Limit(1:limit)
  end
  return q
end

"""
    search(conn, table; limit = Inf, kw...)

Search `nf_fields`, `ec_curvedata`, `lat_lattices_new`, or `lat_genera` using
their parameter registry. Return a vector of database records. Validate the
columns and types against cached connection metadata before issuing the query.
"""
function search(conn::LMFDBConnection, tname::String; limit = Inf, kw...)
  return rowtable(DBInterface.execute(conn.conn, _search_query(conn, tname; limit, kw...)))
end

"""
    count(conn, table; limit = Inf, kw...)

Count records with the same parameter definitions and validation as `search`.
"""
function count(conn::LMFDBConnection, tname::String; limit = Inf, kw...)
  q = _search_query(conn, tname; limit, kw...) |> Group() |> Select(Agg.count())
  return rowtable(DBInterface.execute(conn.conn, q))[1][1]
end


################################################################################
#
#  Parameter type
#
################################################################################

# We need to store more information
# for example search for padic_completions:
# Input: "string"; Backend type: list{text}; allowed search; = or == means input in datastored
#
# for rank
# Input: "int"; backend type: int; allowed search "numeric"
#
# for ramified primes
# input: "list{int}", backend type list{int}; allowed search; overlaps, ..., but should be treated as set
# here i need to parse == as issetequal
#
# for class group structure
# inpt: list{int}, backend type list{int}; allowed search: only == (not set theoretic, but as a list)
# here i need to parse == as really equal? (need to check what they allow)

function _create_cond(v, k, origin, allowed)
  if v isa Base.Fix2 && !(op.f in allowed)
    error("only the following allowed for `$origin`: $(join(allowed, " "))")
  end
  create_cond(v, k)
end

function _create_cond_signed_split(v::Base.Fix2{typeof(==)}, k, kabs, ksign)
  a = v.x
  @assert a isa BigInt
  return LMFDBLite.PredC(kabs, ==(abs(a))) & LMFDBLite.PredC(ksign, ==(sign(a)))
end

function _create_cond_signed_split(v::LMFDBLite.And, k, kabs, ksign)
  LMFDBLite.AndC(_create_cond_signed_split(v.a, k, kabs, ksign),
                 _create_cond_signed_split(v.b, k, kabs, ksign))
end

function _create_cond_signed_split(v::Base.Fix2{typeof(>=)}, k, kabs, ksign)
  a = v.x
  @assert a isa BigInt
  return (LMFDBLite.PredC(kabs, >=(a)) & LMFDBLite.PredC(ksign, ==(1))) |
          (LMFDBLite.PredC(kabs, <=(-a)) & LMFDBLite.PredC(ksign, ==(-1)))
end

function _create_cond_signed_split(v::Base.Fix2{typeof(<=)}, k, kabs, ksign)
  a = v.x
  @assert a isa BigInt
  return (LMFDBLite.PredC(kabs, <=(a)) & LMFDBLite.PredC(ksign, ==(1))) |
          (LMFDBLite.PredC(kabs, >=(-a)) & LMFDBLite.PredC(ksign, ==(-1)))
end

function _create_cond_signed_split(v::Base.Fix2{typeof(<)}, k, kabs, ksign)
  a = v.x
  @assert a isa BigInt
  return (LMFDBLite.PredC(kabs, <(a)) & LMFDBLite.PredC(ksign, ==(1))) |
          (LMFDBLite.PredC(kabs, >(-a)) & LMFDBLite.PredC(ksign, ==(-1)))
end

function _create_cond_signed_split(v::Base.Fix2{typeof(>)}, k, kabs, ksign)
  a = v.x
  @assert a isa BigInt
  return (LMFDBLite.PredC(kabs, >(a)) & LMFDBLite.PredC(ksign, ==(1))) |
          (LMFDBLite.PredC(kabs, <(-a)) & LMFDBLite.PredC(ksign, ==(-1)))
end

function _create_cond_signed_split(v::Base.Fix2{typeof(in)}, k, kabs, ksign, allowed::Vector, error = nothing)
  a = v.x
  if a isa Vector{BigInt}
    return reduce(LMFDBLite.OrC, [_create_cond_signed_split(==(b), k, kabs, ksign) for b in a])
  else
    @assert a isa AbstractUnitRange
    lb = first(a)
    ub = last(a)
    @assert step(a) == 1
    return (LMFDBLite.PredC(kabs, in(max(first(a), 0):last(a))) & LMFDBLite.PredC(ksign, ==(1))) |
           (LMFDBLite.PredC(kabs, in(max(last(-a), 0):first(-a))) & LMFDBLite.PredC(ksign, ==(-1)))
  end
end

function __create_cond_signed_split(v::Base.Fix2{T}, k, kabs, ksign, origin, allowed::Vector) where {T}
  if !(v.f in allowed)
    error("only the following allowed for `$origin`: $(join(allowed, " "))")
  end
  if v.f === in
    return _create_cond_signed_split(v, k, kabs, ksign, allowed)
  end
  return _create_cond_signed_split(v, k, kabs, ksign)
end

function __create_cond_signed_split(v::Integer, k, kabs, ksign, origin, allowed::Vector)
  return __create_cond_signed_split(==(BigInt(v)), k, kabs, ksign, origin, allowed)
end

function __create_cond_trafo(op::Base.Fix2, k, knew, trafo, origin, allowed::Vector)
  if !(op.f in allowed)
    error("only the following allowed for `$origin`: $(join(allowed, " "))")
  end
  return _create_cond_trafo(op, k, knew, trafo)
end

function __create_cond_trafo(v::LMFDBLite.And, k, knew, trafo, origin, allowed::Vector)
  return __create_cond_trafo(v.a, k, knew, trafo, origin, allowed) &
         __create_cond_trafo(v.b, k, knew, trafo, origin, allowed)
end

function __create_cond_trafo(v::LMFDBLite.Or, k, knew, trafo, origin, allowed::Vector)
  return __create_cond_trafo(v.a, k, knew, trafo, origin, allowed) |
         __create_cond_trafo(v.b, k, knew, trafo, origin, allowed)
end

function __create_cond_trafo(val, k, knew, trafo, origin, allowed::Vector)
  # todo: assert the type of val
  return __create_cond_trafo(==(val), k, knew, trafo, origin, allowed)
end

function _create_cond_trafo(op::Base.Fix2, k, knew, trafo)
  if op.f === in
    @assert op.x isa AbstractVector
    # Keep integer intervals compact: BigInt unit ranges become SQL BETWEEN.
    if trafo === BigInt && op.x isa AbstractUnitRange{<:Integer}
      return create_cond(knew, in(BigInt(first(op.x)):BigInt(last(op.x))))
    end
    return create_cond(knew, op.f(trafo.(op.x)))
  else
    return create_cond(knew, op.f(trafo(op.x)))
  end
end

_vec_to_string(v::Vector{<:Integer}) = "[" * join(v, ", ") * "]"

_vec_to_sql_array(v::Vector{<:Integer}) = _stringify_list(v)

function _create_number_field_signature_cond(columns, v, origin, allowed)
  r1, r2 = _signature_values(v, origin, allowed)
  return create_cond(columns[1], ==(r1 + 2r2)) & create_cond(columns[2], ==(r2))
end

function _signature_values(v, origin, allowed)
  if v isa Base.Fix2
    v.f in allowed || error("only the following allowed for `$origin`: $(join(allowed, " "))")
    v = v.x
  end
  if !(v isa Union{Tuple, AbstractVector}) || length(v) != 2 ||
      !all(x -> x isa Integer && x >= 0, v) || all(iszero, v)
    throw(ArgumentError("signature must be a pair of nonnegative integers with positive total"))
  end
  return BigInt.(v)
end

function _create_lattice_signature_cond(columns, v, origin, allowed)
  nplus, nminus = _signature_values(v, origin, allowed)
  return create_cond(columns[1], ==(nplus + nminus)) & create_cond(columns[2], ==(nplus))
end

function _scalar_parameter(T, sqltype, column, allowed = Any[==, <=, >=, >, <, in]; transform = T)
  builder = (k, v, origin, ops) -> __create_cond_trafo(v, k, k, transform, origin, ops)
  return (T, sqltype, column, builder, allowed)
end
