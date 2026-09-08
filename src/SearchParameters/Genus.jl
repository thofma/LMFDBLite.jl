function _genus_parameter_definitions()
  parameter_definitions = _quadratic_parameter_definitions()
  merge!(parameter_definitions, Dict(
    :determinant => _scalar_parameter(BigInt, SQL.bigint, :det),
    :representative_gram_matrix => _scalar_parameter(Vector{BigInt}, SQL.list{SQL.integer}, :rep, Any[==]; transform = _vec_to_sql_array),
    :discriminant_form => _scalar_parameter(Vector{BigInt}, SQL.list{SQL.integer}, :discriminant_form, Any[==]; transform = _vec_to_sql_array),
    :mass => _scalar_parameter(Rational{BigInt}, SQL.list{SQL.numeric}, :mass, Any[==]; transform = x -> _prepare_for_lookup(Rational{BigInt}(x))),
  ))
  parameter_definitions[:det] = parameter_definitions[:determinant]
  parameter_definitions[:rep] = parameter_definitions[:representative_gram_matrix]
  return parameter_definitions
end
