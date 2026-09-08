function _lattice_parameter_definitions()
  parameter_definitions = _quadratic_parameter_definitions()
  merge!(parameter_definitions, Dict(
    :genus_label => _scalar_parameter(String, SQL.text, :genus_label, Any[==, in]),
    :minimum => _scalar_parameter(BigInt, SQL.integer, :minimum),
    :automorphism_group_order => _scalar_parameter(BigInt, SQL.numeric, :aut_size),
    :automorphism_group => _scalar_parameter(String, SQL.text, :aut_label, Any[==, in]),
    :dual_determinant => _scalar_parameter(Float64, SQL.numeric, :dual_det),
    :dual_kissing_number => _scalar_parameter(BigInt, SQL.bigint, :dual_kissing),
    :gram_matrix => _scalar_parameter(Vector{BigInt}, SQL.list{SQL.integer}, :gram, Any[==]; transform = _vec_to_sql_array),
    :kissing_number => _scalar_parameter(BigInt, SQL.bigint, :kissing),
    :festi_veniani_index => _scalar_parameter(BigInt, SQL.numeric, :festi_veniani_index),
  ))
  return parameter_definitions
end
