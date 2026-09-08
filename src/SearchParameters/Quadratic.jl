# Common search parameter definitions for quadratic lattices and their genera.
# These do not describe a separate searchable table.
# `_lattice_parameter_definitions` and `_genus_parameter_definitions` extend
# them with parameters for their tables.
function _quadratic_parameter_definitions()
  parameter_definitions = Dict(
    :label => _scalar_parameter(String, SQL.text, :label, Any[==, in]),
    :rank => _scalar_parameter(BigInt, SQL.smallint, :rank),
    :signature => (Tuple{BigInt, BigInt}, (SQL.smallint, SQL.smallint), (:rank, :nplus), _create_lattice_signature_cond, Any[==]),
    :nplus => _scalar_parameter(BigInt, SQL.smallint, :nplus),
    :level => _scalar_parameter(BigInt, SQL.bigint, :level),
    :class_number => _scalar_parameter(BigInt, SQL.smallint, :class_number),
    :is_even => _scalar_parameter(Bool, SQL.boolean, :is_even, Any[==]),
    :discriminant => _scalar_parameter(BigInt, SQL.bigint, :disc),
    :disc_group_invs => _scalar_parameter(Vector{BigInt}, SQL.list{SQL.integer}, :discriminant_group_invs, Any[==]; transform = _vec_to_sql_array),
    :discriminant_group_exponent => _scalar_parameter(BigInt, SQL.integer, :discriminant_group_exponent),
    :conway_symbol => _scalar_parameter(String, SQL.text, :conway_symbol, Any[==, in]),
    :dual_conway_symbol => _scalar_parameter(String, SQL.text, :dual_conway_symbol, Any[==, in]),
    :scale => _scalar_parameter(BigInt, SQL.integer, :scale),
  )
  parameter_definitions[:disc] = parameter_definitions[:discriminant]
  parameter_definitions[:discriminant_group_invs] = parameter_definitions[:disc_group_invs]
  return parameter_definitions
end
