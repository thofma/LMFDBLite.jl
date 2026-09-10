function _number_field_parameter_definitions()
  # Entries declare (Julia input type, PostgreSQL type(s), column(s), builder, operators).
  return Dict(
    :label => _scalar_parameter(String, LMFDBLite.SQL.text, :label, Any[==, in]),
    :signature => (Tuple{BigInt, BigInt}, (LMFDBLite.SQL.smallint, LMFDBLite.SQL.smallint), (:degree, :r2), _create_number_field_signature_cond, Any[==]),
    :ramified => (Vector{BigInt}, LMFDBLite.SQL.list{LMFDBLite.SQL.numeric}, :ramps, _create_integer_set_cond, Any[issetequal, issubset, issuperset, (==) => issetequal]),
    :class_number => _scalar_parameter(BigInt, LMFDBLite.SQL.numeric, :class_number),
    :class_group => _scalar_parameter(Vector{BigInt}, LMFDBLite.SQL.jsonb, :class_group, Any[==]; transform = _vec_to_string),
    :narrow_class_number => _scalar_parameter(BigInt, LMFDBLite.SQL.bigint, :narrow_class_number),
    # Unlike class_group (JSON), narrow_class_group is a PostgreSQL bigint array.
    :narrow_class_group => _scalar_parameter(Vector{BigInt}, LMFDBLite.SQL.list{LMFDBLite.SQL.bigint}, :narrow_class_group, Any[==]; transform = _vec_to_sql_array),
    :relative_class_number => _scalar_parameter(BigInt, LMFDBLite.SQL.numeric, :relative_class_number),
    :discriminant => (BigInt, (LMFDBLite.SQL.numeric, LMFDBLite.SQL.smallint), (:disc_abs, :disc_sign), (k, v, orig, allowed) -> __create_cond_signed_split(v, k, k[1], k[2], orig, allowed), Any[==, <=, >=, >, <, in]),
    :absolute_discriminant => _scalar_parameter(BigInt, LMFDBLite.SQL.numeric, :disc_abs),
    # Equality and membership compare the stored floating-point root discriminants exactly.
    :root_discriminant => _scalar_parameter(Float64, LMFDBLite.SQL.double, :rd, Any[==, <=, >=, >, <, in]),
    :galois_root_discriminant => _scalar_parameter(Float64, LMFDBLite.SQL.double, :grd, Any[==, <=, >=, >, <, in]),
    :regulator => _scalar_parameter(Float64, LMFDBLite.SQL.numeric, :regulator, Any[==, <=, >=, >, <, in]),
    :degree => (BigInt, LMFDBLite.SQL.smallint, :degree, _create_integer_cond, Any[==, <=, >=, >, <, in]),
    # Galois groups are stored as transitive group labels, e.g. "4T2".
    :galois_group => _scalar_parameter(String, LMFDBLite.SQL.text, :galois_label, Any[==, in]),
    :is_galois => _scalar_parameter(Bool, LMFDBLite.SQL.boolean, :is_galois, Any[==]),
    :is_cyclic => _scalar_parameter(Bool, LMFDBLite.SQL.boolean, :gal_is_cyclic, Any[==]),
    :is_abelian => _scalar_parameter(Bool, LMFDBLite.SQL.boolean, :gal_is_abelian, Any[==]),
    :is_solvable => _scalar_parameter(Bool, LMFDBLite.SQL.boolean, :gal_is_solvable, Any[==]),
    :is_cm => _scalar_parameter(Bool, LMFDBLite.SQL.boolean, :cm, Any[==]),
    :is_minimal_sibling => _scalar_parameter(Bool, LMFDBLite.SQL.boolean, :is_minimal_sibling, Any[==]),
    :index => _scalar_parameter(BigInt, LMFDBLite.SQL.integer, :index),
    :ramified_prime_count => (BigInt, LMFDBLite.SQL.smallint, :num_ram, _create_integer_cond, Any[==, <=, >=, >, <, in])
  )
end
