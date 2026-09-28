module UI

import ..LMFDBLite
using ..LMFDBLite: Tryparse
import Tachikoma as T

include("Fields.jl")
include("Input.jl")
include("SearchForm.jl")
include("SearchUI.jl")

function require_object_conversions()
    Base.get_extension(LMFDBLite, :LMFDBLiteHeckeExt) !== nothing ||
        throw(ArgumentError("Load Hecke or Oscar before searching: using LMFDBLite, Hecke"))
    return nothing
end

function default_count_executors(number_field_counter = LMFDBLite.count_number_fields)
    return Dict{Symbol,Any}(
        :number_fields => number_field_counter,
        :elliptic_curves => LMFDBLite.count_elliptic_curves,
        :elliptic_curves_number_fields => LMFDBLite.count_elliptic_curves_over_number_fields,
        :integer_lattices => LMFDBLite.count_integer_lattices,
        :genera => LMFDBLite.count_genera,
    )
end

function hecke_extension()
    extension = Base.get_extension(LMFDBLite, :LMFDBLiteHeckeExt)
    extension === nothing && error("Load Hecke or Oscar before returning results")
    return extension
end

convert_elliptic_curve_rows(conn, rows) =
    getfield(hecke_extension(), :_elliptic_curve_from_record).(rows)
convert_number_field_elliptic_curve_rows(conn, rows) =
    getfield(hecke_extension(), :_number_field_elliptic_curves)(conn, rows)
convert_integer_lattice_rows(conn, rows) =
    getfield(hecke_extension(), :_lattice_from_record).(rows)
convert_genus_rows(conn, rows) =
    getfield(hecke_extension(), :_genera_from_records)(conn, rows)

function default_result_converters(number_field_converter = LMFDBLite._number_fields_from_rows)
    return Dict{Symbol,Any}(
        :number_fields => (conn, rows) -> number_field_converter(rows),
        :elliptic_curves => convert_elliptic_curve_rows,
        :elliptic_curves_number_fields => convert_number_field_elliptic_curve_rows,
        :integer_lattices => convert_integer_lattice_rows,
        :genera => convert_genus_rows,
    )
end

# Injection stays private: the public UI always uses the cached default connection.
function run_ui(; runner = m -> T.app(m; default_bindings = false),
                 connect = LMFDBLite.lmfdb,
                 execute = search_number_field_rows,
                 execute_count = LMFDBLite.count_number_fields,
                 convert_results = LMFDBLite._number_fields_from_rows,
                 executes = search_executors(execute),
                 execute_counts = default_count_executors(execute_count),
                 result_converters = default_result_converters(convert_results))
    model = SearchUI(; connect, execute, executes)
    runner(model) # Tachikoma restores the terminal before returning (also on errors).
    if model.action == :count && model.submitted !== nothing
        return execute_counts[model.database](connect(); model.submitted...)
    end
    if model.return_to_repl
        connection = model.database == :number_fields ? nothing : connect()
        return result_converters[model.database](connection, model.results)
    end
    return nothing
end

function LMFDBLite.ui()
    require_object_conversions()
    return run_ui()
end

end
