module LMFDBLiteHeckeExt

using Hecke
import LMFDBLite
import LMFDBLite: integer_lattices

include("NumberField.jl")
include("Lattice.jl")
include("Genus.jl")
include("EllipticCurve.jl")

function _bind_hecke_function(name::Symbol)
  f = getproperty(Hecke, name)
  if !isdefined(LMFDBLite, name)
    Core.eval(LMFDBLite, :(const $name = $f))
  end
  @assert getproperty(LMFDBLite, name) === f
  return nothing
end

function __init__()
  # Bind the already-loaded optional dependency's functions at runtime so the
  # parent and Hecke expose the same generics without breaking precompilation.
  for name in (:number_field, :elliptic_curve, :genus)
    _bind_hecke_function(name)
  end
end

end # module LMFDBLiteHeckeExt
