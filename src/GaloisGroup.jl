# LMFDB's familiar group names are parser aliases, rather than rows in a
# dedicated alias table. Each alias below identifies one transitive
# representation; gps_transitive supplies all other representations of the same
# abstract group.
const _SYMMETRIC_TRANSITIVE_NUMBER = Int[
  1, 1, 2, 5, 5, 16, 7, 50, 34, 45, 8, 301, 9, 63, 104, 1954,
  10, 983, 8, 1117, 164, 59, 7, 25000, 211, 96, 2392, 1854, 8,
  5712, 12, 2801324, 162, 115, 407, 121279, 11, 76, 306, 315842,
  10, 9491, 10, 2113, 10923, 56, 6,
]

const _DIHEDRAL_TRANSITIVE_NUMBER = Dict(
  3 => 2, 4 => 3, 5 => 2, 6 => 3, 7 => 2, 8 => 6, 9 => 3,
  10 => 3, 11 => 2, 12 => 12, 13 => 2, 14 => 3, 15 => 2, 16 => 56,
  17 => 2, 18 => 13, 19 => 2, 20 => 10, 21 => 5, 22 => 3, 23 => 2,
  24 => 34, 25 => 4, 26 => 3, 27 => 8, 28 => 10, 29 => 2, 30 => 14,
  31 => 2, 32 => 374, 33 => 3, 34 => 3, 35 => 4, 36 => 47, 37 => 2,
  38 => 3, 39 => 4, 40 => 46, 41 => 2, 42 => 11, 43 => 2, 44 => 9,
  45 => 4, 46 => 3, 47 => 2,
)

const _GALOIS_GROUP_ALIAS_SEEDS = Dict(
  "V4" => "4T2", "C2XC2" => "4T2", "F5" => "5T3",
  "PSL(2,5)" => "5T4", "PGL(2,5)" => "5T5", "F7" => "7T4",
  "GL(3,2)" => "7T5", "PSL(2,7)" => "7T5", "PGL(2,7)" => "8T43",
  "C4XC2" => "8T2", "C2XC2XC2" => "8T3", "Q8" => "8T5",
  "SL(2,3)" => "8T12", "GL(2,3)" => "8T23", "C3XC3" => "9T2",
  "S3XC3" => "6T5", "S3XS3" => "6T9", "M9" => "9T14",
  "PSL(2,8)" => "9T27", "PSL(2,9)" => "6T15",
  "PGL(2,9)" => "10T30", "M10" => "10T31", "F11" => "11T4",
  "PSL(2,11)" => "11T5", "M11" => "11T6", "C6XC2" => "12T2",
  "C3:C4" => "12T5", "F13" => "13T6", "PSL(2,13)" => "14T30",
  "PGL(2,13)" => "14T39", "Q8XC2" => "16T7", "C4:C4" => "16T8",
  "Q16" => "16T14", "F17" => "17T5", "PSL(2,17)" => "17T6",
  "PGL(2,17)" => "18T468", "C5:C4" => "20T2",
  "PGL(2,19)" => "20T362", "F23" => "23T3", "Q8XC3" => "24T4",
  "C3:Q8" => "24T5", "C3:C8" => "24T8", "C7:C4" => "28T3",
  "Q32" => "32T51", "C5:C8" => "40T3", "M12" => "12T295",
  "M22" => "22T38", "M23" => "23T5", "M24" => "24T24680",
  "PSL(3,3)" => "13T7", "PSP(4,3)" => "27T993",
  "PSU(3,3)" => "28T323", "SL(2,5)" => "24T201",
  "GL(2,5)" => "24T1353",
)

function _family_galois_group_alias(code::String)
  m = match(r"^([ACDS])(\d+)$", code)
  m === nothing && return nothing
  family = only(m.captures[1])
  n = tryparse(Int, m.captures[2])
  n === nothing && return nothing
  if family == 'C' && 1 <= n <= 47
    return n == 32 ? "32T33" : "$(n)T1"
  elseif family == 'S' && 1 <= n <= length(_SYMMETRIC_TRANSITIVE_NUMBER)
    return "$(n)T$(_SYMMETRIC_TRANSITIVE_NUMBER[n])"
  elseif family == 'A'
    n in (1, 2) && return "1T1"
    3 <= n <= length(_SYMMETRIC_TRANSITIVE_NUMBER) &&
      return "$(n)T$(_SYMMETRIC_TRANSITIVE_NUMBER[n] - 1)"
  elseif family == 'D'
    n == 1 && return "2T1"
    n == 2 && return "4T2"
    haskey(_DIHEDRAL_TRANSITIVE_NUMBER, n) &&
      return "$(n)T$(_DIHEDRAL_TRANSITIVE_NUMBER[n])"
  end
  return nothing
end

function _galois_group_alias_seed(code::String)
  # LMFDB treats direct-product aliases independently of factor order.
  factors = split(code, 'X')
  normalized = join(sort(factors; rev = true), 'X')
  return get(_GALOIS_GROUP_ALIAS_SEEDS, normalized,
             _family_galois_group_alias(normalized))
end

function _split_galois_group_codes(input::String)
  codes = String[]
  start = firstindex(input)
  depth = 0
  for i in eachindex(input)
    c = input[i]
    if c in ('[', '(')
      depth += 1
    elseif c in (']', ')')
      depth -= 1
      depth < 0 && throw(ArgumentError("invalid Galois group code `$input`"))
    elseif c == ',' && depth == 0
      code = input[start:prevind(input, i)]
      isempty(code) && throw(ArgumentError("invalid Galois group code `$input`"))
      push!(codes, code)
      start = nextind(input, i)
    end
  end
  depth == 0 || throw(ArgumentError("invalid Galois group code `$input`"))
  code = input[start:lastindex(input)]
  isempty(code) && throw(ArgumentError("invalid Galois group code `$input`"))
  push!(codes, code)
  return codes
end

function _gps_transitive_query(conn::LMFDBConnection, column::Symbol, value::String)
  "gps_transitive" in conn.table_names || throw(ArgumentError(
    "resolving Galois group aliases and abstract labels requires table `gps_transitive` in schema `$(conn.schema)`"))
  q = From("gps_transitive") |>
      _create_where([create_cond(column, value)]) |>
      Select(Get(:label), Get(:abstract_label))
  return rowtable(DBInterface.execute(conn.conn, q))
end

function _labels_for_abstract_group(conn::LMFDBConnection, abstract_label::String)
  rows = _gps_transitive_query(conn, :abstract_label, lowercase(abstract_label))
  return String[String(row.label) for row in rows]
end

function _labels_for_alias(conn::LMFDBConnection, alias::String, seed::String)
  rows = _gps_transitive_query(conn, :label, seed)
  isempty(rows) && throw(ArgumentError(
    "cannot resolve Galois group alias `$alias`: `$seed` is absent from `gps_transitive`"))
  abstract_labels = unique(String(row.abstract_label) for row in rows)
  length(abstract_labels) == 1 || throw(ArgumentError(
    "cannot resolve Galois group alias `$alias`: `$seed` has ambiguous abstract-group data"))
  return _labels_for_abstract_group(conn, only(abstract_labels))
end

function _complete_galois_group_code(conn::LMFDBConnection, code::String)
  m = match(r"^(\d+)[T](\d+)$", code)
  m !== nothing && return ["$(m.captures[1])T$(m.captures[2])"]

  m = match(r"^\[(\d+),(\d+)\]$", code)
  m !== nothing && return _labels_for_abstract_group(
    conn, "$(m.captures[1]).$(m.captures[2])")

  m = match(r"^(\d+)\.([0-9A-Z]+)$", code)
  m !== nothing && return _labels_for_abstract_group(
    conn, "$(m.captures[1]).$(lowercase(m.captures[2]))")

  seed = _galois_group_alias_seed(code)
  seed === nothing && throw(ArgumentError("unknown Galois group code `$code`"))
  return _labels_for_alias(conn, code, seed)
end

function _transitive_label_key(label::String)
  m = match(r"^(\d+)T(\d+)$", label)
  m === nothing && return (big(typemax(Int)), big(typemax(Int)), label)
  return (parse(BigInt, m.captures[1]), parse(BigInt, m.captures[2]), label)
end

"""
    galois_group_labels(conn, code)

Resolve an LMFDB Galois-group code to its stored transitive-group labels. Accept
`nTj` labels, GAP SmallGroup IDs such as `"[8,3]"` and `"8.3"`, familiar names
such as `"C3"`, and comma-separated combinations. Canonical `nTj` labels need
only `nf_fields`; other forms use `gps_transitive` in the connection's schema.
"""
function galois_group_labels(conn::LMFDBConnection, input::AbstractString)
  normalized = uppercase(replace(String(input), r"\s+" => ""))
  isempty(normalized) && throw(ArgumentError("Galois group code must not be empty"))
  return lock(conn.galois_group_cache_lock) do
    labels = get!(conn.galois_group_cache, normalized) do
      result = String[]
      for code in _split_galois_group_codes(normalized)
        append!(result, _complete_galois_group_code(conn, code))
      end
      sort!(unique!(result); by = _transitive_label_key)
    end
    return copy(labels)
  end
end

function _resolve_galois_group_condition(conn::LMFDBConnection, value, origin)
  if value isa Union{And, Or}
    return typeof(value)(_resolve_galois_group_condition(conn, value.a, origin),
                         _resolve_galois_group_condition(conn, value.b, origin))
  end
  condition = value isa Base.Fix2 ? value : ==(value)
  op = _search_operator(condition.f, origin, Any[==, in])
  if op === in
    condition.x isa AbstractVector || throw(ArgumentError(
      "search parameter `$origin` requires a vector for membership"))
    labels = String[]
    for code in condition.x
      append!(labels, galois_group_labels(conn, _search_value(code, String, origin)))
    end
    sort!(unique!(labels); by = _transitive_label_key)
    return in(labels)
  end
  labels = galois_group_labels(conn, _search_value(condition.x, String, origin))
  return length(labels) == 1 ? ==(only(labels)) : in(labels)
end

function _resolve_search_parameter(conn::LMFDBConnection, tname::String,
                                   parameter::Symbol, value)
  if tname == "nf_fields" && parameter == :galois_group
    return _resolve_galois_group_condition(conn, value, parameter)
  end
  return value
end
