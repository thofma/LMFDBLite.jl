function _number_field_from_record(record::NamedTuple)
  f = Hecke.Globals.Qx(BigInt.(record[:coeffs]))
  K, = number_field(f; cached = false)
  set_attribute!(K, :lmfdb_label => record[:label])
  return K
end

function LMFDBLite.number_fields(db::LMFDBLite.LMFDBConnection; limit = Inf, kw...)
  res = LMFDBLite.new_search(db, "nf_fields"; limit, kw...)
  return _number_field_from_record.(res)
end
