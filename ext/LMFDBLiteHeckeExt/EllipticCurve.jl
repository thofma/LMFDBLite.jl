function _elliptic_curve_from_record(record::NamedTuple)
  E = Hecke.elliptic_curve(BigInt.(record.ainvs))
  Hecke.set_attribute!(E, :lmfdb_label => record.lmfdb_label)
  return E
end

"""
    elliptic_curve(conn::LMFDBConnection, label::String)

Return the elliptic curve over the rationals with the given LMFDB label, such
as `"11.a2"`, and attach the label as its `:lmfdb_label` attribute.
"""
function Hecke.elliptic_curve(conn::LMFDBLite.LMFDBConnection, label::String)
  records = LMFDBLite.search(conn, "ec_curvedata"; label, limit = 2)
  length(records) <= 1 || error("LMFDB label is not unique")
  isempty(records) && error("label does not exist")
  return _elliptic_curve_from_record(only(records))
end

function LMFDBLite.elliptic_curves(conn::LMFDBLite.LMFDBConnection; limit = Inf, kw...)
  records = LMFDBLite.search(conn, "ec_curvedata"; limit, kw...)
  return _elliptic_curve_from_record.(records)
end
