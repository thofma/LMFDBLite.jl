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

"""
    allof(condition, conditions...)

Combine one or more search conditions for one parameter with logical AND,
including nested `allof` and [`anyof`](@ref) expressions. Each
condition is validated by the search parameter's builder; bare values mean equality.

Return a single argument unchanged. Calling `allof()` raises `ArgumentError`.

# Examples
```julia
LMFDBLite.search(conn, "nf_fields"; class_number = allof(>=(2), <=(5), in([2, 3, 4])))
```
"""
allof(condition, conditions...) = foldl(And, conditions; init = condition)
allof() = throw(ArgumentError("allof requires at least one condition"))

"""
    anyof(condition, conditions...)

Combine one or more search conditions for one parameter with logical OR,
including nested [`allof`](@ref) and `anyof` expressions. Each
condition is validated by the search parameter's builder; bare values mean equality.

Return a single argument unchanged. Calling `anyof()` raises `ArgumentError`.

# Examples
```julia
LMFDBLite.search(conn, "nf_fields"; class_number = anyof(==(1), ==(2)))
LMFDBLite.search(conn, "nf_fields"; signature = anyof((2, 0), (0, 1)))
```
"""
anyof(condition, conditions...) = foldl(Or, conditions; init = condition)
anyof() = throw(ArgumentError("anyof requires at least one condition"))

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
    throw(ArgumentError("Table with name $(tname) does not exist in schema $(conn.schema); see `table_names`"))
  end
end

function check_table_column_name(conn::LMFDBConnection, tname::String, column::Symbol)
  layout = table_layout(conn, tname)
  if !(LMFDBLite.SQL.FieldName(column) in keys(layout))
    throw(ArgumentError("Table $(tname) does not have a column named \"$(column)\". See `table_layout`."))
  end
end

"""
    table_layout(conn, table)

Return the column types of `table` in `conn.schema`. Load metadata on first use
and cache it for the lifetime of the connection. An unsupported column type
raises an error only when that table's layout is requested.
"""
function table_layout(conn::LMFDBConnection, tname::String)
  check_table_name(conn, tname)
  return lock(conn.table_layout_lock) do
    layout = get!(conn.table_layouts, (conn.schema, tname)) do
      query_table_layout(conn, tname)
    end
    return layout.data
  end
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

function _search_parameter_definitions(tname::String)
  if tname == "nf_fields"
    return _number_field_parameter_definitions()
  elseif tname == "lat_lattices_new"
    return _lattice_parameter_definitions()
  elseif tname == "lat_genera"
    return _genus_parameter_definitions()
  elseif tname == "ec_curvedata"
    return _elliptic_curve_parameter_definitions()
  elseif tname == "ec_nfcurves"
    return _number_field_elliptic_curve_parameter_definitions()
  end
  throw(ArgumentError("search has no parameter definitions for table `$tname`"))
end

"""
    check_search_parameters(conn, table)

Check all parameter declarations for `table` against its PostgreSQL metadata in
`conn.schema`. Fetch and cache that table's layout on first use; later calls reuse
it. Return `nothing` on success, or report the parameter, column, and expected
type on a mismatch. Open a new connection to check a changed database schema.
"""
function check_search_parameters(conn::LMFDBConnection, tname::String)
  parameter_definitions = _search_parameter_definitions(tname)
  layout = table_layout(conn, tname)
  for (parameter, spec) in parameter_definitions
    _check_parameter_schema(layout, tname, parameter, spec)
  end
  return nothing
end

"""
    check_number_field_parameters(conn)

Check all number field declarations using `check_search_parameters(conn, "nf_fields")`.
"""
check_number_field_parameters(conn::LMFDBConnection) = check_search_parameters(conn, "nf_fields")

function _search_query(conn::LMFDBConnection, tname::String, apply_order::Bool = true;
                       limit = Inf, order_by = nothing, kw...)
  parameter_definitions = _search_parameter_definitions(tname)
  layout = table_layout(conn, tname)
  conds = Condition[]
  for (parameter, value) in kw
    haskey(parameter_definitions, parameter) || throw(ArgumentError("unknown search parameter `$parameter` for table `$tname`"))
    spec = parameter_definitions[parameter]
    _check_parameter_schema(layout, tname, parameter, spec)
    _, _, column, builder, allowed = spec
    value = _resolve_search_parameter(conn, tname, parameter, value)
    # Builders receive physical column(s), the user value, its public parameter
    # name (for errors), and allowed operators. They return a Condition tree.
    cond = builder(column, value, parameter, allowed)
    columns, _ = _parameter_columns_and_types(spec)
    _assert_parameter_columns(cond, columns, parameter)
    push!(conds, cond)
  end
  # Validate ordering for searches and counts alike. Counts omit the ORDER BY
  # itself because even a capped count is independent of which rows come first.
  order_terms = _order_terms(tname, parameter_definitions, layout, order_by)
  q = From(tname) |> _create_where(conds)
  if apply_order && !isempty(order_terms)
    q = q |> Order(order_terms...)
  end
  if limit != Inf
    q = q |> Limit(1:limit)
  end
  return q
end

# Parameter values are normally ready for their pure condition builders. A small
# number need connection-backed normalization first; methods live with the
# corresponding parameter implementation.
_resolve_search_parameter(conn, tname, parameter, value) = value

"""
    search(conn, table; limit = Inf, order_by = nothing, kw...)

Search `nf_fields`, `ec_curvedata`, `ec_nfcurves`, `lat_lattices_new`, or `lat_genera` using
their parameter definitions. Return a vector of database records. Validate the
columns and types against the table's cached metadata before issuing the query,
loading the layout on first use. Tables are resolved in `conn.schema`.

`order_by` accepts a public parameter symbol (ascending), a pair such as
`:rank => :desc`, or a tuple/vector of these in priority order. Directions must
be `:asc` or `:desc`. Numeric, text, and boolean parameters are supported;
signed discriminants sort by their signed value. Arrays, signatures, and
stored rational pairs are not supported as sort keys. Text uses the database's
text ordering, including for labels and text-encoded invariants.

Sorting happens before `limit`. Missing values come last in both directions,
and ascending `id` breaks ties. Custom databases must provide a unique non-null
integer `id` column for ordered searches. `nothing` (the default) or an empty
tuple/vector leaves the query unordered; a finite limit then selects an
unspecified subset. The Hecke conversion functions forward `order_by` and
preserve the resulting order.
"""
function search(conn::LMFDBConnection, tname::String; limit = Inf, order_by = nothing, kw...)
  return rowtable(DBInterface.execute(conn.conn, _search_query(conn, tname; limit, order_by, kw...)))
end

"""
    count(conn, table; limit = Inf, order_by = nothing, kw...)

Count records with the same parameter definitions and validation as `search`.
With `limit = n`, count at most `n` matching records (a capped count). Leave
`limit = Inf` to count every match. The same rule applies to the type-specific
`count_number_fields`, `count_elliptic_curves`,
`count_elliptic_curves_over_number_fields`, `count_integer_lattices`, and `count_genera` functions.
`order_by` is accepted and validated as for `search`, but counting never sorts
the records because ordering does not change the count.
"""
function count(conn::LMFDBConnection, tname::String; limit = Inf, order_by = nothing, kw...)
  q = _search_query(conn, tname, false; limit, order_by, kw...) |> Group() |> Select(Agg.count())
  return rowtable(DBInterface.execute(conn.conn, q))[1][1]
end


################################################################################
#
#  Condition normalization and construction
#
################################################################################

# Pipeline: keyword value -> parameter builder -> Condition tree -> FunSQL -> SQL.
#
# Each parameter definition declares an input type, SQL type(s), physical column(s),
# builder, and allowed operators. _search_query checks the cached schema before
# calling the builder, then verifies that its Condition uses only declared columns.
# The declared input type describes the parameter; the builder performs conversion.
#
# All parameter builders use two passes:
#   1. _normalize_condition wraps bare values in equality, validates operators and
#      resolves aliases, and converts operands throughout the input And/Or tree.
#   2. _build_condition maps each normalized Fix2 predicate to a Condition. A leaf
#      can expand into several column predicates (sets, signed values, signatures).
# Normalization finishes first so an invalid branch is rejected even if another
# branch makes the result constant. Operands remain Julia values until lowering.
#
# Scalar builders convert to the declared input type during normalization and
# apply any storage encoding in the leaf builder. Conditions.jl translates the
# result to FunSQL with create_fun; _create_where joins keyword conditions with AND.
# No database connection is needed to normalize, build, or render a tree.
#
# When adding a parameter, declare every column it uses and choose a builder that
# matches its semantics: integer sets ignore order and duplicates, while structured
# arrays such as class groups retain them. Keep parameter-specific storage encoding
# in the leaf builder.

# Operator pairs in a parameter definition map an accepted spelling to its canonical
# operator, e.g. == => issetequal.
function _search_operator(op, origin, allowed)
  for entry in allowed
    if entry isa Pair
      op === first(entry) && return last(entry)
    elseif op === entry
      return op
    end
  end
  throw(ArgumentError("only the following allowed for `$origin`: $(join(allowed, " "))"))
end

# normalize_operand(canonical_operator, value, origin) returns the converted
# operand. It validates its shape; origin is the keyword name used in errors.
function _normalize_condition(v::Base.Fix2, origin, allowed, normalize_operand)
  op = _search_operator(v.f, origin, allowed)
  return Base.Fix2(op, normalize_operand(op, v.x, origin))
end

function _normalize_condition(v::Union{And, Or}, origin, allowed, normalize_operand)
  return typeof(v)(_normalize_condition(v.a, origin, allowed, normalize_operand),
                   _normalize_condition(v.b, origin, allowed, normalize_operand))
end

_normalize_condition(v, origin, allowed, normalize_operand) =
  _normalize_condition(==(v), origin, allowed, normalize_operand)

# leaf_builder accepts a normalized Fix2 and returns a Condition on physical
# columns. The input And/Or nodes become AndC/OrC through the Condition operators.
_build_condition(leaf_builder, v::Base.Fix2) = leaf_builder(v)

function _build_condition(leaf_builder, v::And)
  return _build_condition(leaf_builder, v.a) & _build_condition(leaf_builder, v.b)
end

function _build_condition(leaf_builder, v::Or)
  return _build_condition(leaf_builder, v.a) | _build_condition(leaf_builder, v.b)
end

# These leaves require BigInt operands. Discriminants are nonzero and stored as
# sign and absolute value; comparisons reverse direction on the negative branch.
# Build predicates on those columns directly rather than multiplying them in SQL.
function _create_cond_signed_split(v::Base.Fix2{typeof(==)}, k, kabs, ksign)
  a = v.x
  @assert a isa BigInt
  return LMFDBLite.PredC(kabs, ==(abs(a))) & LMFDBLite.PredC(ksign, ==(sign(a)))
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

function _create_cond_signed_split(v::Base.Fix2{typeof(in)}, k, kabs, ksign)
  a = v.x
  isempty(a) && return FalseC()
  if a isa Vector{BigInt}
    return reduce(LMFDBLite.OrC, [_create_cond_signed_split(==(b), k, kabs, ksign) for b in a])
  else
    @assert a isa AbstractUnitRange{BigInt}
    lb = first(a)
    ub = last(a)
    positive = max(lb, 0):ub
    negative = max(-ub, 0):(-lb)
    pos = isempty(positive) ? FalseC() : PredC(kabs, in(positive)) & PredC(ksign, ==(1))
    neg = isempty(negative) ? FalseC() : PredC(kabs, in(negative)) & PredC(ksign, ==(-1))
    return pos | neg
  end
end

# BigInt(x) is the conversion hook, including for types supplied by optional
# packages (such as Oscar/Hecke's ZZRingElem), without requiring Integer subtyping.
function _search_bigint(x, origin)
  try
    return BigInt(x)
  catch err
    err isa Union{MethodError, InexactError, ArgumentError, DomainError, OverflowError} || rethrow()
    throw(ArgumentError("search parameter `$origin` requires values convertible to BigInt; cannot convert $(typeof(x))"))
  end
end

function _normalize_integer_operand(op, a, origin)
  if op !== in
    return _search_bigint(a, origin)
  end
  if a isa AbstractRange
    # Convert endpoints without iterating the range, before any sign arithmetic.
    # Ascending BigInt unit ranges are rendered as BETWEEN by create_fun.
    # Every scalar integer parameter uses this policy: other steps are rejected,
    # even for empty or singleton ranges. Explicit vectors retain discrete membership.
    stride = _search_bigint(step(a), origin)
    abs(stride) == 1 || throw(ArgumentError("search parameter `$origin` supports only unit-step ranges; use an explicit vector for stepped membership"))
    isempty(a) && return BigInt[]
    lb = _search_bigint(first(a), origin)
    ub = _search_bigint(last(a), origin)
    return stride == 1 ? (lb:ub) : (ub:lb)
  elseif a isa AbstractVector
    return BigInt[_search_bigint(x, origin) for x in a]
  end
  throw(ArgumentError("search parameter `$origin` requires a vector or unit-step range for membership"))
end

function _normalize_integer_array_operand(op, a, origin)
  if !(a isa AbstractVector) || a isa AbstractRange
    throw(ArgumentError("search parameter `$origin` requires an explicit vector of values convertible to BigInt"))
  end
  return BigInt[_search_bigint(x, origin) for x in a]
end

function _create_integer_cond(k, v, origin, allowed)
  normalized = _normalize_condition(v, origin, allowed, _normalize_integer_operand)
  return _build_condition(normalized) do op
    op.f === in && isempty(op.x) ? FalseC() : create_cond(k, op)
  end
end

function _create_integer_set_cond(k, v, origin, allowed)
  normalized = _normalize_condition(v, origin, allowed, _normalize_integer_array_operand)
  return _build_condition(normalized) do op
    values = _vec_to_sql_array(op.x)
    if op.f === issetequal
      # Mutual containment implements set equality, including duplicate operands.
      return create_cond(k, issuperset(values)) & create_cond(k, issubset(values))
    end
    # Retain containment even for []: inclusion is true for non-null arrays,
    # while containment in [] (and set equality with []) selects empty arrays.
    return create_cond(k, Base.Fix2(op.f, values))
  end
end

function __create_cond_signed_split(v, k, kabs, ksign, origin, allowed::Vector)
  normalized = _normalize_condition(v, origin, allowed, _normalize_integer_operand)
  return _build_condition(normalized) do op
    _create_cond_signed_split(op, k, kabs, ksign)
  end
end

function _search_value(value, ::Type{T}, origin) where T
  try
    return T(value)
  catch err
    # Only input-conversion failures become ArgumentError. Internal assertions
    # and unrelated exceptions must remain visible as implementation errors.
    err isa Union{MethodError, InexactError, ArgumentError, DomainError, OverflowError} || rethrow()
    throw(ArgumentError("search parameter `$origin` requires a value convertible to $T; got $(typeof(value))"))
  end
end

_search_value(value, ::Type{Vector{BigInt}}, origin) =
  _normalize_integer_array_operand(==, value, origin)

function _create_transformed_cond(k, value, origin, allowed, T, transform)
  function normalize_operand(op, operand, origin)
    if op === in
      operand isa AbstractVector ||
        throw(ArgumentError("search parameter `$origin` requires a vector for membership"))
      return [_search_value(x, T, origin) for x in operand]
    end
    return _search_value(operand, T, origin)
  end
  normalized = _normalize_condition(value, origin, allowed, normalize_operand)
  return _build_condition(normalized) do op
    if op.f === in
      isempty(op.x) && return FalseC()
      return create_cond(k, in(transform.(op.x)))
    end
    return create_cond(k, Base.Fix2(op.f, transform(op.x)))
  end
end

_vec_to_string(v::Vector{<:Integer}) = "[" * join(v, ", ") * "]"

_vec_to_sql_array(v::Vector{<:Integer}) = _stringify_list(v)

function _create_number_field_signature_cond(columns, v, origin, allowed)
  normalized = _normalize_condition(v, origin, allowed, _normalize_signature_operand)
  return _build_condition(normalized) do op
    r1, r2 = op.x
    # Keep both column restrictions together within each signature alternative.
    return create_cond(columns[1], ==(r1 + 2r2)) & create_cond(columns[2], ==(r2))
  end
end

function _normalize_signature_operand(op, v, origin)
  if !(v isa Union{Tuple, AbstractVector}) || length(v) != 2 ||
      !all(x -> x isa Integer && x >= 0, v) || all(iszero, v)
    throw(ArgumentError("search parameter `$origin` requires a pair of nonnegative integers with positive total"))
  end
  return BigInt.(v)
end

function _create_lattice_signature_cond(columns, v, origin, allowed)
  normalized = _normalize_condition(v, origin, allowed, _normalize_signature_operand)
  return _build_condition(normalized) do op
    nplus, nminus = op.x
    return create_cond(columns[1], ==(nplus + nminus)) & create_cond(columns[2], ==(nplus))
  end
end

function _scalar_parameter(T, sqltype, column, allowed = Any[==, <=, >=, >, <, in]; transform = T)
  # Integer conversion must inspect range endpoints and step before any broadcast.
  # This also handles Hecke/Oscar ranges whose elements are not subtypes of Integer.
  builder = transform === BigInt ? _create_integer_cond :
            (k, v, origin, ops) -> _create_transformed_cond(k, v, origin, ops, T, transform)
  return (T, sqltype, column, builder, allowed)
end
