function _elliptic_curve_from_record(record::NamedTuple)
  E = Hecke.elliptic_curve(BigInt.(record.ainvs))
  Hecke.set_attribute!(E, :lmfdb_label => record.lmfdb_label)
  return E
end

"""
    elliptic_curve(conn::LMFDBConnection, label::String)

Return the elliptic curve with the given LMFDB label, such as `"11.a2"` over
the rationals or `"2.2.5.1-31.1-a1"` over a number field, and attach the label
as its `:lmfdb_label` attribute. For a number field curve, construct its base
field from the defining polynomial in `nf_fields` and label that field too.
"""
function Hecke.elliptic_curve(conn::LMFDBLite.LMFDBConnection, label::String)
  over_number_field = occursin(r"^\d+\.\d+\.\d+\.\d+-", label)
  table = over_number_field ? "ec_nfcurves" : "ec_curvedata"
  records = LMFDBLite.search(conn, table; label, limit = 2)
  length(records) <= 1 || error("LMFDB label is not unique")
  isempty(records) && error("label does not exist")
  if over_number_field
    return only(_number_field_elliptic_curves(conn, records))
  end
  return _elliptic_curve_from_record(only(records))
end

function LMFDBLite.elliptic_curves(conn::LMFDBLite.LMFDBConnection; limit = Inf, kw...)
  records = LMFDBLite.search(conn, "ec_curvedata"; limit, kw...)
  return _elliptic_curve_from_record.(records)
end

function LMFDBLite.elliptic_curves_over_number_fields(conn::LMFDBLite.LMFDBConnection; limit = Inf, kw...)
  records = LMFDBLite.search(conn, "ec_nfcurves"; limit, kw...)
  return _number_field_elliptic_curves(conn, records)
end

# LMFDB encodes c0 + c1*a + ... as "c0,c1,...", using the defining polynomial
# of the labelled nf_fields record. Parse integers and fractions exactly;
# these strings are data, never Julia expressions to evaluate.
# Format: https://github.com/LMFDB/lmfdb/blob/main/lmfdb/ecnf/WebEllipticCurve.py
function _parse_number_field_element(K::Hecke.AbsSimpleNumField, value::AbstractString)
  coefficients = split(value, ',')
  length(coefficients) <= Hecke.degree(K) ||
    throw(ArgumentError("too many power-basis coefficients for a field of degree $(Hecke.degree(K))"))
  rationals = map(coefficients) do coefficient
    fraction = split(coefficient, '/')
    length(fraction) in (1, 2) || throw(ArgumentError("invalid rational coefficient in number field record"))
    numerator = parse(BigInt, fraction[1])
    denominator = length(fraction) == 1 ? BigInt(1) : parse(BigInt, fraction[2])
    iszero(denominator) && throw(ArgumentError("zero denominator in number field record"))
    return Hecke.QQ(numerator, denominator)
  end
  return K(Hecke.Globals.Qx(rationals))
end

function _number_field_elliptic_curve_from_record(record::NamedTuple, K::Hecke.AbsSimpleNumField)
  coefficients = split(record.ainvs, ';')
  length(coefficients) == 5 || throw(ArgumentError("expected five a-invariants in elliptic curve record $(record.label)"))
  E = Hecke.elliptic_curve([_parse_number_field_element(K, a) for a in coefficients])
  Hecke.set_attribute!(E, :lmfdb_label => record.label)
  return E
end

function _number_field_elliptic_curves(conn, records)
  # Scope the field cache to this result batch: one lookup and one parent per
  # distinct field, without sharing metadata across connections or later calls.
  fields = Dict{String, Hecke.AbsSimpleNumField}()
  curves = Hecke.EllipticCurve{Hecke.AbsSimpleNumFieldElem}[]
  for record in records
    K = get!(fields, record.field_label) do
      Hecke.number_field(conn, record.field_label)
    end
    push!(curves, _number_field_elliptic_curve_from_record(record, K))
  end
  return curves
end
