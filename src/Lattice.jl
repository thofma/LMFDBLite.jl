function _lattice_from_record(record::NamedTuple)
  r = Int(record[:rank])
  G = matrix(ZZ, r, r, record[:gram])
  L = integer_lattice(;gram = G)
  if record[:genus_label] != nothing
    set_attribute!(L, :lmfdb_genus_label => record[:genus_label])
  end
  set_attribute!(L, :lmfdb_label => record[:label])
  return L
end

function Hecke.integer_lattice(db, label::String)
  res = LMFDBLite.search(db, "lat_lattices_new"; label = ==(label))
  @assert length(res) <= 1
  if length(res) == 0
    error("label does not exist")
  end
  return _lattice_from_record(res[1])
end

function integer_lattices(db; kw...)
  if get(kw, :raw, false)
    res = LMFDBLite.search(db, "lat_lattices_new"; kw...)
  else
    kw = _validate_parameters(lattice_search_parameter(), kw)
    res = LMFDBLite.search(db, "lat_lattices_new"; kw...)
  end
  return _lattice_from_record.(res)
end

function lattice_search_parameter()
  return LMFDBLite.SearchParameterConfig(Dict(
      (:limit => (LMFDBLite.SInt, :limit, identity)),
      (:label => (LMFDBLite.SLMFDBLite.String, :label, identity)),
      (:rank => (LMFDBLite.SInt, :rank, identity)),
      (:signature => (LMFDBLite.SPair{LMFDBLite.SInt}, :nplus, x -> x[1])),
      #(:determinant, (LMFDBLite.SInt, identity)),
      (:level => (LMFDBLite.SInt, :level, identity)),
      (:class_number => (LMFDBLite.SInt, :class_number, identity)),
      (:minimum => (LMFDBLite.SInt, :minimum, identity)),
      (:is_even => (LMFDBLite.SBool, :is_even, identity)),
      (:automorphism_group_order => (LMFDBLite.SInt, :aut_size, identity)),
      (:automorphism_group => (LMFDBLite.SGroup, :aut_label, identity)),
      (:dual_determinant => (LMFDBLite.SInt, :dual_det, identity)),
      (:dual_kissing_number => (LMFDBLite.SInt, :dual_kissing, identity)),
      (:disc_group_invs => (LMFDBLite.SList{LMFDBLite.SPosInt}, :discriminant_group_invs, identity)),
      (:gram_matrix => (LMFDBLite.SList{LMFDBLite.SInt}, :gram, identity)),
      (:kissing_number => (LMFDBLite.SInt, :kissing, identity)),
      (:festi_veniani_index => (LMFDBLite.SInt, :festi_veniani_index, identity)),
     ))
end

  #for op in Any[==, <=, <, >=, >, !=] 
    #if v isa Base.Fix2{typeof(op)}

function _disc_helper(v::Base.Fix2{typeof(==)})
  a = v.x
  @assert a isa BigInt
  return LMFDBLite.PredC(:disc_abs, ==(abs(a))) & LMFDBLite.PredC(:disc_sign, ==(sign(a)))
end

function _disc_helper(v::LMFDBLite.And)
  LMFDBLite.AndC(_disc_helper(v.a), _disc_helper(v.b))
end

function _disc_helper(v::Base.Fix2{typeof(>=)})
  a = v.x
  @assert a isa BigInt
  return (LMFDBLite.PredC(:disc_abs, >=(a)) & LMFDBLite.PredC(:disc_sign, ==(1))) |
          (LMFDBLite.PredC(:disc_abs, <=(-a)) & LMFDBLite.PredC(:disc_sign, ==(-1)))
end

function _disc_helper(v::Base.Fix2{typeof(<=)})
  a = v.x
  @assert a isa BigInt
  return (LMFDBLite.PredC(:disc_abs, <=(a)) & LMFDBLite.PredC(:disc_sign, ==(1))) |
          (LMFDBLite.PredC(:disc_abs, >=(-a)) & LMFDBLite.PredC(:disc_sign, ==(-1)))
end

function _disc_helper(v::Base.Fix2{typeof(<)})
  a = v.x
  @assert a isa BigInt
  return (LMFDBLite.PredC(:disc_abs, <(a)) & LMFDBLite.PredC(:disc_sign, ==(1))) |
          (LMFDBLite.PredC(:disc_abs, >(-a)) & LMFDBLite.PredC(:disc_sign, ==(-1)))
end

function _disc_helper(v::Base.Fix2{typeof(>)})
  a = v.x
  @assert a isa BigInt
  return (LMFDBLite.PredC(:disc_abs, >(a)) & LMFDBLite.PredC(:disc_sign, ==(1))) |
          (LMFDBLite.PredC(:disc_abs, <(-a)) & LMFDBLite.PredC(:disc_sign, ==(-1)))
end

function _disc_helper(v::Base.Fix2{typeof(in)})
  a = v.x
  if a isa Vector{BigInt}
    return reduce(LMFDBLite.OrC, [_disc_helper(==(b)) for b in a])
  else
    @assert a isa AbstractUnitRange
    lb = first(a)
    ub = last(a)
    @assert step(a) == 1
    return (LMFDBLite.PredC(:disc_abs, in(max(first(a), 0):last(a))) & LMFDBLite.PredC(:disc_sign, ==(1))) |
           (LMFDBLite.PredC(:disc_abs, in(max(last(-a), 0):first(-a))) & LMFDBLite.PredC(:disc_sign, ==(-1)))
  end
end

function _disc_helper(v)
  @info typeof(v)
  error("sdas")
end

function _unramified_helper()
end

#   FieldName(:coeffs)                => list{numeric}()
#  FieldName(:embeddings_gen_real)   => list{double}()
#  FieldName(:narrow_class_number)   => bigint()
#  FieldName(:num_ram)               => smallint()
#  FieldName(:subfield_mults)        => list{integer}()
#  FieldName(:relative_class_number) => numeric()
#  FieldName(:used_grh)              => boolean()
#  FieldName(:class_number)          => numeric()
#  FieldName(:conductor)             => numeric()
#  FieldName(:iso_number)            => smallint()
#  FieldName(:r2)                    => smallint()
#  FieldName(:minimal_sibling)       => list{numeric}()
#  FieldName(:is_minimal_sibling)    => boolean()
#  FieldName(:disc_sign)             => smallint()
#  FieldName(:gal_is_solvable)       => boolean()
#  FieldName(:embeddings_gen_imag)   => list{double}()
#  FieldName(:galt)                  => integer()
#  FieldName(:inessentialp)          => list{integer}()
#  FieldName(:monogenic)             => smallint()
#  FieldName(:subfields)             => list{text}()
#  FieldName(:index)                 => integer()
#  FieldName(:torsion_order)         => smallint()
#  FieldName(:regulator)             => numeric()
#  FieldName(:local_algs)            => list{text}()
#  FieldName(:degree)                => smallint()
#  FieldName(:class_group)           => jsonb()
#  FieldName(:id)                    => bigint()
#  FieldName(:label)                 => text()
#  FieldName(:rd)                    => double()
#  FieldName(:is_galois)             => boolean()
#  FieldName(:narrow_class_group)    => list{bigint}()
#  FieldName(:maximal_cm_subfield)   => list{numeric}()
#  FieldName(:disc_abs)              => numeric()
#  FieldName(:gal_is_abelian)        => boolean()
#  FieldName(:gal_is_cyclic)         => boolean()
#  FieldName(:cm)                    => boolean()
#  FieldName(:disc_rad)              => numeric()
#  FieldName(:ramps)                 => list{numeric}()
#  FieldName(:galois_label)          => text()
#  FieldName(:galois_disc_exponents) => list{numeric}()
#  FieldName(:grd)                   => double()


function number_field_search_parameters()
  return LMFDBLite.SearchParameterConfig(Dict(
      :limit => (LMFDBLite.SInt, :limit, identity),
      :degree => (LMFDBLite.SInt, :degree, identity),
      :signature => (LMFDBLite.SPair{LMFDBLite.SInt}, :r2, x -> x[2]),
      :discriminant => (LMFDBLite.SInt, _disc_helper, identity),
      :root_discriminant => (LMFDBLite.SReal, :rd, identity),
      :galois_group => (LMFDBLite.SString, :galois_label, identity),
      :is_cyclic => (LMFDBLite.Bool, :gal_is_cyclic, identity),
      :is_abelian => (LMFDBLite.Bool, :gal_is_abelian, identity),
      #:is_multi_quadratic => (LMFDBLite.Bool, :gal_is_abelian, identity)
      #:is_dihedral_non_galois => (LMFDBLite.Bool, :
      #:is_dihedral => (LMFDBLite.Bool, :
      :is_galois => (LMFDBLite.Bool, :is_galois, identity),
      #:is_solvable => (LMFDBLite.Bool, :is_galois, identity),
      #:is_nonsolvable => (LMFDBLite.Bool, :is_galois, identity),
      :ramified_prime_count => (LMFDBLite.SInt, :num_ram, identity),
      :galois_root_discriminant => (LMFDBLite.SReal, :grd, identity),
      :class_number => (LMFDBLite.SInt, :class_number, identity),
      :class_group_structure => (LMFDBLite.SString, :class_group, identity),
      :narrow_class_number => (LMFDBLite.SInt, :class_number, identity),
      :narrow_class_group_structure => (LMFDBLite.SList{LMFDBLite.SInt}, :class_group, identity),
      :ramified => (LMFDBLite.SSet{LMFDBLite.SInt}, :ramps, identity),
      :unramified => (LMFDBLite.SList{LMFDBLite.SInt}, _unramified_helper, identity),
      :regulator => (LMFDBLite.SReal, :regulator, identity),
      :is_cm => (LMFDBLite.SBool, :cm, identity),
      :padic_completions => (LMFDBLite.SSet{LMFDBLite.SString}, :local_algs, identity), # ??? maybe local_algs?
      :relative_class_number => (LMFDBLite.SInt, :relative_class_number, identity),
      :index => (LMFDBLite.SInt, :index, identity),
      :intermediate_field => (LMFDBLite.SSet{LMFDBLite.SString}, :subfields, identity),
      #:monogenic => (LMFDBLite.SSet{LMFDBLite.SString}
      #Monogenic  # yes # yes or unknown # no or unknown # no # unknown
      :inessential_primes => (LMFDBLite.SSet{LMFDBLite.SInt}, :inessentialp, identity),
      :minimal_sibling => (LMFDBLite.SBool, :is_minimal_sibling, identity),
         ))
end

function number_fields(db; limit = Inf, kw...)
  if get(kw, :raw, false)
    res = LMFDBLite.search(db, "nf_fields"; kw...)
  else
    @info "asdsoo"
    cond = LMFDBLite._validate_parameters(number_field_search_parameters(), kw)
    @info cond
    res = LMFDBLite._search(db, "nf_fields"; limit, cond)
  end
  return _number_field_from_record.(res)
end

