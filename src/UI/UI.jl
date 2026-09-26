module UI

import ..LMFDBLite
using ..LMFDBLite: Tryparse
import Tachikoma as T

include("Fields.jl")
include("Input.jl")
include("NumberFieldForm.jl")
include("SearchUI.jl")

function require_number_fields()
    hasmethod(LMFDBLite.number_fields, Tuple{LMFDBLite.LMFDBConnection}) ||
        throw(ArgumentError("Load Hecke or Oscar before searching: using LMFDBLite, Hecke"))
    return nothing
end

# Injection stays private: the public UI always uses the cached default connection.
function run_ui(; runner = m -> T.app(m; default_bindings = false),
                 connect = LMFDBLite.lmfdb,
                 execute = search_number_field_rows,
                 execute_count = LMFDBLite.count_number_fields,
                 convert_results = LMFDBLite._number_fields_from_rows)
    model = SearchUI(; connect, execute)
    runner(model) # Tachikoma restores the terminal before returning (also on errors).
    if model.action == :count && model.submitted !== nothing
        return execute_count(connect(); model.submitted...)
    end
    return model.return_to_repl ? convert_results(model.results) : nothing
end

function LMFDBLite.ui()
    require_number_fields()
    return run_ui()
end

end
