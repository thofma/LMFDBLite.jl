function _number_field_from_record(record::NamedTuple)
  f = Hecke.Globals.Qx(BigInt.(record[:coeffs]))
  K, = number_field(f; cached = false)
  set_attribute!(K, :lmfdb_label => record[:label])
  return K
end

LMFDBLite._number_fields_from_rows(records::AbstractVector{<:NamedTuple}) =
  _number_field_from_record.(records)

"""
    number_field(conn::LMFDBConnection, label::String)

Return the number field with the given LMFDB label, such as `"2.2.5.1"`, and
attach the label as its `:lmfdb_label` attribute.
"""
function Hecke.number_field(conn::LMFDBLite.LMFDBConnection, label::String)
  records = LMFDBLite.search(conn, "nf_fields"; label, limit = 2)
  length(records) <= 1 || error("LMFDB label is not unique")
  isempty(records) && error("label does not exist")
  return _number_field_from_record(only(records))
end

function LMFDBLite.number_fields(conn::LMFDBLite.LMFDBConnection; limit = Inf, kw...)
  records = LMFDBLite.search(conn, "nf_fields"; limit, kw...)
  return LMFDBLite._number_fields_from_rows(records)
end
