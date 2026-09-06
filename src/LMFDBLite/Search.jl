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

abstract type SearchParameter end

struct SInt <: SearchParameter end

struct SSet{T} <: SearchParameter end

struct SPosInt <: SearchParameter end

struct SReal <: SearchParameter end

struct SPair{T} <: SearchParameter end

struct SBool <: SearchParameter end

struct SGroup <: SearchParameter end

struct SList{T} <: SearchParameter end

struct SString <: SearchParameter end

struct SearchParameterConfig
  data::Dict{Symbol, Tuple{Any#=SearchParameter=#, Union{Symbol, Function}, Any#=Function=#}}
end

function _validate_parameters(parameter_config::LMFDBLite.SearchParameterConfig, kw)
  res = Condition[]
  for (k, v) in kw
    @info "" k
    if !haskey(parameter_config.data, k)
      throw(ArgumentError("$(k) is not a valid parameter"))
    end
    T, kk, trafo = parameter_config.data[k]
    if kk isa Symbol
      #@info T, kk, trafo
      v = _validate_parameter(v, T, trafo)
      #@info kk, v
      push!(res, create_cond(kk, v))
    else
      @info v, T
      @info _validate_parameter(v, T, trafo)
      # kk is a function returning new paris kkk, vv
      push!(res, kk(_validate_parameter(v, T, trafo)))
    end
  end
  return res
end

function _validate_parameter(v, T, trafo)
  if v isa LMFDBLite.And
    return __validate_parameter_and(v, T, trafo)
  else
    __validate_parameter(v, T, trafo)
  end
end

function __validate_parameter(v, ::Type{SString}, trafo)
  return v
end

function __validate_parameter(v, ::Type{SSet{String}}, trafo)
end

function __validate_parameter(v, ::Type{SList{SInt}}, trafo)
  return v
end

function __validate_parameter(v, ::Type{SBool}, trafo)
  @assert v isa Bool
  return v
end

function __validate_parameter(v::String, ::Type{SSet{SString}}, trafo)
  return contains(v)
end

function __validate_parameter(v, ::Type{SPair{SInt}}, trafo)
  if v isa Tuple
    return trafo(BigInt.(v))
  end
  for op in Any[==, <=, <, >=, >, !=] 
    if v isa Base.Fix2{typeof(op)}
      # condition is of the form op(op.x)
      # so op.x must be a scalar
      #if !_is_scalar_type(v.x)
      #  error("must be scalar")
      #end
      return op(trafo(BigInt.(v.x)))
    end
  end
  for op in Any[in]
    if v isa Base.Fix2{typeof(op)}
      # condition is of the form op(op.x)
      # so op.x must be a scalar
      #@info v.x
      #if !_is_scalar_array_type(v.x)
      #  error("must be scalar array type")
      #end
      return op(trafo.((z -> BigInt.(z)).(v.x)))
    end
  end
  error("asds")
end

function __validate_parameter(v, ::Type{SInt}, trafo)
  @info "asds"
  if v isa Number
    return BigInt(trafo(v))
  end
  for op in Any[==, <=, <, >=, >, !=] 
    if v isa Base.Fix2{typeof(op)}
      # condition is of the form op(op.x)
      # so op.x must be a scalar
      #if !_is_scalar_type(v.x)
      #  error("must be scalar")
      #end
      return op(trafo(BigInt(v.x)))
    end
  end
  for op in Any[in]
    if v isa Base.Fix2{typeof(op)}
      # condition is of the form op(op.x)
      # so op.x must be a scalar
      #@info v.x
      #if !_is_scalar_array_type(v.x)
      #  error("must be scalar array type")
      #end
      if v.x isa AbstractUnitRange
        @assert trafo === identity
        return op((convert(UnitRange{BigInt}, (v.x))))
      else
        return op(trafo.(BigInt.(v.x)))
      end
    end
  end
  error("asds")
end

function __validate_parameter_and(v::LMFDBLite.And, T, trafo)
  v1 = _validate_parameter(v.a, T, trafo)
  v2 = _validate_parameter(v.b, T, trafo)
  return v1 & v2
end

################################################################################
#
#  Formalizatin of restrictions
#
################################################################################


# struct And
#   a
#   b
# end
# 
# Base.:&(a::Function, b::Function) = And(a, b)
# 
# struct Or
#   a
#   b
# end
# 
# Base.:|(a::Function, b::Function) = Or(a, b)

function issuperset(x, y)
  return issubset(y, x)
end

issuperset(x) = Base.Fix2(issuperset, x)

export issuperset

export includes

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

function _prepare_for_in_check(x::Vector{Int})
  return x
end

# FunSQL does not like Vector, so we turn it into a list by hand
function _stringify_list(a::Vector)
  return "{" * join(a, ",") * "}"
end

function _create_where(kw)
  r = []
  for (k, v) in kw
    # Some special case to allow rank = 2 instead of rank = ==(2)
    if v isa Number #|| v isa String
      v = ==(v)
    end
    push!(r, create_fun(k, v))
  end
  return Where(Fun.and(r...))
end

################################################################################
#
#  Search
#
################################################################################

function check_table_name(db::LMFDBConnection, tname::String)
  if !(tname in db.table_names)
    throw(ArgumentError("Table with name $(tname) does not exist; see `tables_names`"))
  end
end

function check_table_column_name(db::LMFDBConnection, tname::String, column::Symbol)
  layout = db.table_layouts[tname].data # Dict{FieldName, SQL.ValueType}
  if !(LMFDBLite.SQL.FieldName(column) in keys(layout))
    throw(ArgumentError("Table $(tname) does not have a column named \"$(column)\". See `table_layout`."))
  end
end

function table_layout(db::LMFDBConnection, tname::String)
  check_table_name(db, tname)
  return db.table_layouts[tname].data
end

function _search(db::LMFDBConnection, tname::String; limit = Inf, cond::Vector{LMFDBLite.Condition})
  check_table_name(db, tname)
  #for (k, _) in kw
  #  check_table_column_name(db, tname, k)
  #end
  @info "sss"

  q = From(tname) |> 
      _create_where(cond)
  if limit != Inf
    q = q |> Limit(1:limit)
  end
  return rowtable(DBInterface.execute(db.conn, q))
end

function search(db::LMFDBConnection, tname::String; limit = Inf, kw...)
  check_table_name(db, tname)
  for (k, _) in kw
    check_table_column_name(db, tname, k)
  end

  q = From(tname) |> 
      _create_where(kw)
  if limit != Inf
    q = q |> Limit(1:limit)
  end
  return rowtable(DBInterface.execute(db.conn, q))
end

function count(db::LMFDBConnection, tname::String; limit = Inf, kw...)
  check_table_name(db, tname)
  for (k, _) in kw
    check_table_column_name(db, tname, k)
  end

  q = From(tname) |> 
      _create_where(kw)
  if limit != Inf
    q = q |> Limit(1:limit)
  end
  q = q |> Group() |> Select(Agg.count())
  return rowtable(DBInterface.execute(db.conn, q))[1][1]
end

function new_search(db::LMFDBConnection, tname::String; limit = Inf, kw...)
  check_table_name(db, tname)
  #for (k, _) in kw
  #  check_table_column_name(db, tname, k)
  #end

  conds = Condition[]
  D = _new_number_field_parameters()
  for (k, v) in kw
    if haskey(D, k)
      _, _, kk, f, allowedthings = D[k]
      cond = f(kk, v, k, allowedthings)
      push!(conds, cond)
    else
      error("key $k makes no sense")
    end
  end
  @show typeof(conds)
  return _search(db, tname; limit = limit, cond = conds)
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
  return _create_cond_signed_split(v, k, kabs, ksign, allowed)
end

function __create_cond_trafo(op::Base.Fix2, k, knew, trafo, origin, allowed::Vector)
  if !(op.f in allowed)
    error("only the following allowed for `$origin`: $(join(allowed, " "))")
  end
  return _create_cond_trafo(op, k, knew, trafo)
end

function __create_cond_trafo(val, k, knew, trafo, origin, allowed::Vector)
  # todo: assert the type of val
  return __create_cond_trafo(==(val), k, knew, trafo, origin, allowed)
end

function _create_cond_trafo(op::Base.Fix2, k, knew, trafo)
  if op.f === in
    @assert op.x isa Vector
    return create_cond(knew, op.f(trafo.(op.x)))
  else
    return create_cond(knew, op.f(trafo(op.x)))
  end
end

function _create_cond_trafo(v::LMFDBLite.And, k, knew, trafo)
  return _create_cond_trafo(v.a, k, knew, trafo) & _create_cond_trafo(v.b, k, knew, trafo)
end

function _create_cond_trafo(v::LMFDBLite.Or, k, knew, trafo)
  return _create_cond_trafo(v.a, k, knew, trafo) | _create_cond_trafo(v.b, k, knew, trafo)
end

function _new_lattice_parameters()
  return Dict(
      #(:limit => (LMFDBLite.SInt, :limit, identity)),
      #(:label => (LMFDBLite.SLMFDBLite.String, :label, identity)),
    :label => (String, LMFDBLite.String, :label, _create_cond, Any[==]),
      #(:rank => (LMFDBLite.SInt, :rank, identity)),
    :rank => (Int, LMFDBLite.SInt, :rank, _create_cond, Any[==, <=, >=, >, <, in]),
      #(:signature => (LMFDBLite.SPair{LMFDBLite.SInt}, :nplus, x -> x[1])),
      :signature => (Tuple{Int, Int}, LMFDBLite.SPair{LMFDBLite.SInt}, (k, v) -> _create_cond_trafo(v, k, :nplus, x -> x[1]), Any[==, <=, >=, >, <, in]),
      ##(:determinant, (LMFDBLite.SInt, identity)),
      #(:level => (LMFDBLite.SInt, :level, identity)),
    :level => (BigInt, LMFDBLite.SInt, :level, _create_cond, Any[==, <=, >=, >, <, in]),
      #(:class_number => (LMFDBLite.SInt, :class_number, identity)),
    :class_number => (BigInt, LMFDBLite.SInt, :class_number, _create_cond, Any[==, <=, >=, >, <, in]),
      #(:minimum => (LMFDBLite.SInt, :minimum, identity)),
    :minimum => (BigInt, LMFDBLite.SInt, :minimum, _create_cond, Any[==, <=, >=, >, <, in]),
      #(:is_even => (LMFDBLite.SBool, :is_even, identity)),
    :is_even => (Bool, LMFDBLite.SBool, :is_even, _create_cond, Any[==]),
      #(:automorphism_group_order => (LMFDBLite.SInt, :aut_size, identity)),
    :automorphism_group_order => (BigInt, LMFDBLite.SInt, :aut_size, _create_cond, Any[==, <=, >=, >, <, in]),
      #(:automorphism_group => (LMFDBLite.SGroup, :aut_label, identity)),
    :automorphism_group => (String, LMFDBLite.SGroup, :aut_label, _create_cond, Any[==]),
      #(:dual_determinant => (LMFDBLite.SInt, :dual_det, identity)),
    :dual_determinant => (BigInt, LMFDBLite.SInt, :dual_det, _create_cond, Any[==, <=, >=, >, <, in]),
      #(:dual_kissing_number => (LMFDBLite.SInt, :dual_kissing, identity)),
    :dual_kissing_number => (BigInt, LMFDBLite.SInt, :dual_kissing, _create_cond, Any[==, <=, >=, >, <, in]),
      #(:disc_group_invs => (LMFDBLite.SList{LMFDBLite.SPosInt}, :discriminant_group_invs, identity)),
    :disc_group_invs => (Vector{BigInt}, LMFDBLite.SList{LMFDBLite.SPosInt}, :discriminant_group_invs, _create_cond, [==]),
      #(:gram_matrix => (LMFDBLite.SList{LMFDBLite.SInt}, :gram, identity)),
    :gram_matrix => (Vector{BigInt}, LMFDBLite.SList{LMFDBLite.SInt}, :gram, _create_cond, Any[==]),
      #(:kissing_number => (LMFDBLite.SInt, :kissing, identity)),
    :kissing_number => (BigInt, LMFDBLite.SInt, :kissing, _create_cond, Any[==]),
      #(:festi_veniani_index => (LMFDBLite.SInt, :festi_veniani_index, identity)),
    :festi_veniani_index => (BigInt, LMFDBLite.SInt, :festi_veniani_index, _create_cond, Any[==]),
     )
end

_vec_to_string(v::Vector{<:Integer}) = "[" * join(v, ", ") * "]"

function _new_number_field_parameters()
  return Dict(
    :ramified => (Vector{BigInt}, LMFDBLite.SList{LMFDBLite.SInt}, :ramps, _create_cond, Any[issetequal, issubset, issuperset, (==) => issetequal]), # where should I put the information that == might be issetequal?
    :class_group => (Vector{BigInt}, LMFDBLite.SQL.jsonb, :class_group, (k, v, orig, allowed) -> __create_cond_trafo(v, k, k, _vec_to_string, orig, allowed), Any[==]),
    :discriminant => (BigInt, LMFDBLite.SInt, missing, (k, v, orig, allowed) -> __create_cond_signed_split(v, k, :disc_abs, :disc_sign, orig, allowed), Any[==, <=, >=, >, <, in]),
    :degree => (BigInt, LMFDBLite.SInt, :degree, _create_cond, Any[==, <=, >=, >, <, in]), 
    :ramified_prime_count => (BigInt, LMFDBLite.SInt, :num_ram, _create_cond, Any[==, <=, >=, >, <, in])
     )
end
