abstract type Condition end

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
    @info cond
    push!(r, create_fun(cond))
  end
  return Where(Fun.and(r...))
end
