# (:id, :label, :degree, :r2, :cm, :iso_number, :disc_abs, :disc_sign, :disc_rad, :galt, :class_number, :class_group, :used_grh, :rd, :regulator, :ramps, :coeffs, :num_ram, :conductor, :subfields, :subfield_mults, :torsion_order, :galois_label, :is_galois, :gal_is_abelian, :gal_is_cyclic, :gal_is_solvable, :local_algs, :inessentialp, :index, :monogenic, :embeddings_gen_real, :embeddings_gen_imag, :is_minimal_sibling, :minimal_sibling, :galois_disc_exponents, :grd, :relative_class_number, :narrow_class_number, :narrow_class_group, :maximal_cm_subfield)

function _number_field_from_record(record::NamedTuple)
  f = Hecke.Globals.Qx(BigInt.(record[:coeffs]))
  K, = number_field(f; cached = false)
  set_attribute!(K, :lmfdb_label => record[:label])
  return K
end

function Hecke.number_field(db, label::String)
  res = LMFDBLite.search(db, "nf_fields"; label = label)
  @assert length(res) <= 1
  if length(res) == 0
    error("label does not exist")
  end
  return _number_field_from_record(res[1])
end

#function number_fields(db; kw...)
#  res = LMFDBLite.search(db, "nf_fields"; kw...)
#  return _number_field_from_record.(res)
#end
