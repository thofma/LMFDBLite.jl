using LMFDBLite
using DBInterface
using Test

include("parameter_consistency.jl")
include("connection_options.jl")
include("metadata.jl")
if haskey(ENV, "LMFDB_POSTGRES_BIN")
    include("metadata_postgresql.jl")
end
include("discriminants.jl")
include("number_field_conditions.jl")
include("galois_groups.jl")
include("composition.jl")
include("integer_ranges.jl")

include("search_inputs.jl")
include("elliptic_curve_number_field_conditions.jl")
include("ordering.jl")
