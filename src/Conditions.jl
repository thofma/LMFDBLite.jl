# Builders produce this tree over physical columns. PredC stores a column and
# its predicate; AndC/OrC combine conditions, including expansions of a single
# user predicate into several column predicates. create_fun renders the tree to
# FunSQL, and _create_where combines the separate keyword conditions with AND.
struct AndC <: Condition
  a
  b
end

struct OrC <: Condition
  a
  b
end

struct PredC <: Condition
  symb
  op
end

# A column-free false predicate, used for empty scalar membership. Empty operands
# of set containment retain their predicates because their truth values differ.
struct FalseC <: Condition end

# This checks column ownership after building; operator and operand validation
# belongs to the parameter builder, before SQL rendering.
_assert_parameter_columns(::FalseC, columns, parameter) = nothing

function _assert_parameter_columns(c::PredC, columns, parameter)
  @assert c.symb in columns "search parameter `$parameter` produced a condition for undeclared column `$(c.symb)`"
  return nothing
end

function _assert_parameter_columns(c::Union{AndC, OrC}, columns, parameter)
  _assert_parameter_columns(c.a, columns, parameter)
  _assert_parameter_columns(c.b, columns, parameter)
  return nothing
end

function create_cond(symb, v::Union{String, Number})
  return create_cond(symb, ==(v))
end

function create_cond(symb, v::Base.Fix2)
  return PredC(symb, v)
end

function create_cond(symb, v::And)
  return create_cond(symb, v.a) & create_cond(symb, v.b)
end

function create_cond(symb, v::Or)
  return create_cond(symb, v.a) | create_cond(symb, v.b)
end

function create_fun(c::PredC)
  return create_fun(c.symb, c.op)
end

create_fun(::FalseC) = FunSQL.Lit(false)

function create_fun(c::AndC)
  return Fun.and(create_fun(c.a), create_fun(c.b))
end

function create_fun(c::OrC)
  return Fun.or(create_fun(c.a), create_fun(c.b))
end

Base.:&(a::Condition, b::Condition) = AndC(a, b)

Base.:|(a::Condition, b::Condition) = OrC(a, b)

function _create_where(conds::Vector)
  r = []
  for cond in conds
    push!(r, create_fun(cond))
  end
  return Where(Fun.and(r...))
end
