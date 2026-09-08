function _number_field_parameters()
  # Entries declare (Julia input type, PostgreSQL type(s), column(s), builder, operators).
  return Dict(
    :label => (String, LMFDBLite.SQL.text, :label, (k, v, orig, allowed) -> __create_cond_trafo(v, k, k, identity, orig, allowed), Any[==, in]),
    :signature => (Tuple{BigInt, BigInt}, (LMFDBLite.SQL.smallint, LMFDBLite.SQL.smallint), (:degree, :r2), _create_number_field_signature_cond, Any[==]),
    :ramified => (Vector{BigInt}, LMFDBLite.SQL.list{LMFDBLite.SQL.numeric}, :ramps, _create_integer_set_cond, Any[issetequal, issubset, issuperset, (==) => issetequal]),
    :class_number => (BigInt, LMFDBLite.SQL.numeric, :class_number, (k, v, orig, allowed) -> __create_cond_trafo(v, k, k, BigInt, orig, allowed), Any[==, <=, >=, >, <, in]),
    :class_group => (Vector{BigInt}, LMFDBLite.SQL.jsonb, :class_group, (k, v, orig, allowed) -> __create_cond_trafo(v, k, k, _vec_to_string, orig, allowed), Any[==]),
    :narrow_class_number => (BigInt, LMFDBLite.SQL.bigint, :narrow_class_number, (k, v, orig, allowed) -> __create_cond_trafo(v, k, k, BigInt, orig, allowed), Any[==, <=, >=, >, <, in]),
    # Unlike class_group (JSON), narrow_class_group is a PostgreSQL bigint array.
    :narrow_class_group => (Vector{BigInt}, LMFDBLite.SQL.list{LMFDBLite.SQL.bigint}, :narrow_class_group, (k, v, orig, allowed) -> __create_cond_trafo(v, k, k, _vec_to_sql_array, orig, allowed), Any[==]),
    :relative_class_number => (BigInt, LMFDBLite.SQL.numeric, :relative_class_number, (k, v, orig, allowed) -> __create_cond_trafo(v, k, k, BigInt, orig, allowed), Any[==, <=, >=, >, <, in]),
    :discriminant => (BigInt, (LMFDBLite.SQL.numeric, LMFDBLite.SQL.smallint), (:disc_abs, :disc_sign), (k, v, orig, allowed) -> __create_cond_signed_split(v, k, k[1], k[2], orig, allowed), Any[==, <=, >=, >, <, in]),
    # Equality and membership compare the stored floating-point root discriminants exactly.
    :root_discriminant => (Float64, LMFDBLite.SQL.double, :rd, (k, v, orig, allowed) -> __create_cond_trafo(v, k, k, Float64, orig, allowed), Any[==, <=, >=, >, <, in]),
    :galois_root_discriminant => (Float64, LMFDBLite.SQL.double, :grd, (k, v, orig, allowed) -> __create_cond_trafo(v, k, k, Float64, orig, allowed), Any[==, <=, >=, >, <, in]),
    :regulator => (Float64, LMFDBLite.SQL.numeric, :regulator, (k, v, orig, allowed) -> __create_cond_trafo(v, k, k, Float64, orig, allowed), Any[==, <=, >=, >, <, in]),
    :degree => (BigInt, LMFDBLite.SQL.smallint, :degree, _create_integer_cond, Any[==, <=, >=, >, <, in]),
    # Galois groups are stored as transitive group labels, e.g. "4T2".
    :galois_group => (String, LMFDBLite.SQL.text, :galois_label, (k, v, orig, allowed) -> __create_cond_trafo(v, k, k, identity, orig, allowed), Any[==, in]),
    :is_galois => (Bool, LMFDBLite.SQL.boolean, :is_galois, (k, v, orig, allowed) -> __create_cond_trafo(v, k, k, Bool, orig, allowed), Any[==]),
    :is_cyclic => (Bool, LMFDBLite.SQL.boolean, :gal_is_cyclic, (k, v, orig, allowed) -> __create_cond_trafo(v, k, k, Bool, orig, allowed), Any[==]),
    :is_abelian => (Bool, LMFDBLite.SQL.boolean, :gal_is_abelian, (k, v, orig, allowed) -> __create_cond_trafo(v, k, k, Bool, orig, allowed), Any[==]),
    :is_solvable => (Bool, LMFDBLite.SQL.boolean, :gal_is_solvable, (k, v, orig, allowed) -> __create_cond_trafo(v, k, k, Bool, orig, allowed), Any[==]),
    :is_cm => (Bool, LMFDBLite.SQL.boolean, :cm, (k, v, orig, allowed) -> __create_cond_trafo(v, k, k, Bool, orig, allowed), Any[==]),
    :is_minimal_sibling => (Bool, LMFDBLite.SQL.boolean, :is_minimal_sibling, (k, v, orig, allowed) -> __create_cond_trafo(v, k, k, Bool, orig, allowed), Any[==]),
    :index => (BigInt, LMFDBLite.SQL.integer, :index, (k, v, orig, allowed) -> __create_cond_trafo(v, k, k, BigInt, orig, allowed), Any[==, <=, >=, >, <, in]),
    :ramified_prime_count => (BigInt, LMFDBLite.SQL.smallint, :num_ram, _create_integer_cond, Any[==, <=, >=, >, <, in])
  )
end
