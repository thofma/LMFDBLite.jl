# The default suite never opens a database connection. Integration checks are
# separate opt-ins; connection overrides alone do not enable network access.
include("core.jl")
include("hecke.jl")

if get(ENV, "LMFDB_TEST_LIVE", "false") == "true"
    include("live.jl")
end
if get(ENV, "LMFDB_TEST_PUBLIC_DEFAULT", "false") == "true"
    include("default_connection.jl")
end
