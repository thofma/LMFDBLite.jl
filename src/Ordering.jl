# Ordering uses public search names, but must describe their values rather than
# reuse condition builders: a signed discriminant, for example, is a product
# of two stored columns. Structured encodings need their own ordering semantics.
function _normalize_order_by(order_by)
  order_by === nothing && return Pair{Symbol, Symbol}[]
  entries = if order_by isa Union{Symbol, Pair}
    (order_by,)
  elseif order_by isa Union{Tuple, AbstractVector}
    order_by
  else
    throw(ArgumentError("`order_by` requires a parameter symbol, a parameter => :asc/:desc pair, or a tuple/vector of these"))
  end
  result = Pair{Symbol, Symbol}[]
  for entry in entries
    if entry isa Symbol
      push!(result, entry => :asc)
    elseif entry isa Pair && first(entry) isa Symbol &&
           last(entry) isa Symbol && last(entry) in (:asc, :desc)
      push!(result, entry)
    else
      throw(ArgumentError("invalid `order_by` entry; use a parameter symbol or parameter => :asc/:desc"))
    end
  end
  return result
end

function _order_expression(table, parameter, spec)
  columns, sqltypes = _parameter_columns_and_types(spec)
  if parameter === :discriminant && table in ("nf_fields", "ec_curvedata")
    # Both tables store the absolute value as numeric and the sign separately.
    return Fun."*"(Get(columns[1]), Get(columns[2]))
  elseif length(columns) == 1 && only(sqltypes) in
      (SQL.smallint, SQL.integer, SQL.bigint, SQL.numeric, SQL.real,
       SQL.double, SQL.boolean, SQL.text)
    return Get(only(columns))
  end
  throw(ArgumentError("`order_by` does not support parameter `$parameter` for table `$table`; use a scalar numeric, text, or boolean parameter"))
end

function _order_terms(table, definitions, layout, order_by)
  entries = _normalize_order_by(order_by)
  terms = FunSQL.SQLNode[]
  isempty(entries) && return terms
  seen = Set{Tuple}()
  for (parameter, direction) in entries
    haskey(definitions, parameter) ||
      throw(ArgumentError("unknown `order_by` parameter `$parameter` for table `$table`"))
    spec = definitions[parameter]
    expression = _order_expression(table, parameter, spec)
    _check_parameter_schema(layout, table, parameter, spec)
    columns, _ = _parameter_columns_and_types(spec)
    columns in seen && throw(ArgumentError("duplicate `order_by` parameter `$parameter` (possibly through an alias)"))
    push!(seen, columns)
    push!(terms, expression |> FunSQL.Sort(direction; nulls = :last))
  end
  # The supported LMFDB tables have a unique, non-null integer id. Appending it
  # makes ties deterministic, including when all requested values are NULL.
  # Custom databases must retain this property to provide the same guarantee.
  id_type = get(layout, SQL.FieldName(:id), nothing)
  id_type isa Union{SQL.smallint, SQL.integer, SQL.bigint} ||
    throw(ArgumentError("`order_by` requires an integer `id` column in table `$table` for stable tie-breaking"))
  push!(terms, Get(:id) |> FunSQL.Asc(nulls = :last))
  return terms
end
