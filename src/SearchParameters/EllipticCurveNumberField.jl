# ec_nfcurves has its own encodings: torsion and signatures are JSON arrays,
# while a-invariants and j-invariants are text in the labelled field's power basis.
function _number_field_elliptic_curve_parameter_definitions()
  parameter_definitions = Dict(
    :label => _scalar_parameter(String, SQL.text, :label, Any[==, in]),
    :field_label => _scalar_parameter(String, SQL.text, :field_label, Any[==, in]),
    :degree => _scalar_parameter(BigInt, SQL.smallint, :degree),
    :signature => (Tuple{BigInt, BigInt}, SQL.jsonb, :signature, _create_number_field_curve_signature_cond, Any[==]),
    :conductor_label => _scalar_parameter(String, SQL.text, :conductor_label, Any[==, in]),
    :conductor_norm => _scalar_parameter(BigInt, SQL.bigint, :conductor_norm),
    :isogeny_class => _scalar_parameter(String, SQL.text, :class_label, Any[==, in]),
    :number => _scalar_parameter(BigInt, SQL.smallint, :number),
    :rank => _scalar_parameter(BigInt, SQL.smallint, :rank),
    :analytic_rank => _scalar_parameter(BigInt, SQL.smallint, :analytic_rank),
    :torsion_order => _scalar_parameter(BigInt, SQL.smallint, :torsion_order),
    :torsion_structure => _scalar_parameter(Vector{BigInt}, SQL.jsonb, :torsion_structure, Any[==]; transform = _vec_to_string),
    :torsion_primes => _scalar_parameter(Vector{BigInt}, SQL.list{SQL.integer}, :torsion_primes, Any[==]; transform = _vec_to_sql_array),
    :a_invariants => _scalar_parameter(String, SQL.text, :ainvs, Any[==, in]),
    :j_invariant => _scalar_parameter(String, SQL.text, :jinv, Any[==, in]),
    :cm_discriminant => _scalar_parameter(BigInt, SQL.integer, :cm),
    :isogeny_degrees => _scalar_parameter(Vector{BigInt}, SQL.list{SQL.integer}, :isodeg, Any[==]; transform = _vec_to_sql_array),
    :isogeny_class_degree => _scalar_parameter(BigInt, SQL.integer, :class_deg),
    :isogeny_class_size => _scalar_parameter(BigInt, SQL.smallint, :class_size),
    :regulator => _scalar_parameter(Float64, SQL.numeric, :reg),
    :sha => _scalar_parameter(BigInt, SQL.integer, :sha),
    :semistable => _scalar_parameter(Bool, SQL.boolean, :semistable, Any[==]),
    :potential_good_reduction => _scalar_parameter(Bool, SQL.boolean, :potential_good_reduction, Any[==]),
    :is_q_curve => _scalar_parameter(Bool, SQL.boolean, :q_curve, Any[==]),
    :tamagawa_product => _scalar_parameter(BigInt, SQL.integer, :tamagawa_product),
    :bad_prime_count => _scalar_parameter(BigInt, SQL.integer, :n_bad_primes),
    :nonmaximal_primes => _scalar_parameter(Vector{BigInt}, SQL.list{SQL.smallint}, :nonmax_primes, Any[==]; transform = _vec_to_sql_array),
    :nonmaximal_radical => _scalar_parameter(BigInt, SQL.integer, :nonmax_rad),
    :discriminant_norm => _scalar_parameter(BigInt, SQL.numeric, :normdisc),
  )
  parameter_definitions[:ainvs] = parameter_definitions[:a_invariants]
  parameter_definitions[:jinv] = parameter_definitions[:j_invariant]
  return parameter_definitions
end

function _create_number_field_curve_signature_cond(column, value, origin, allowed)
  normalized = _normalize_condition(value, origin, allowed, _normalize_signature_operand)
  return _build_condition(normalized) do op
    # Here the complete (r1, r2) signature occupies one JSON column.
    return create_cond(column, ==(_vec_to_string(collect(op.x))))
  end
end
