module LMFDBLiteHeckeExt

using Hecke
import LMFDBLite
import LMFDBLite: integer_lattices

include("NumberField.jl")
include("Lattice.jl")
include("Genus.jl")
include("EllipticCurve.jl")

end # module LMFDBLiteHeckeExt
