"""
    elliptic_curves(conn::LMFDBConnection; limit = Inf, order_by = nothing, kw...)

Search the `ec_curvedata` table and convert matching records to Hecke elliptic
curves over the rationals. Load Hecke to enable this method. Parameters,
`limit`, and `order_by` are forwarded to `LMFDBLite.search`; the resulting curves
preserve the requested order.

Common parameters include `label`, `cremona_label`, `isogeny_class`,
`conductor`, `rank`, `analytic_rank`, `torsion_order`, `torsion_structure`,
`a_invariants`, `j_invariant`, `discriminant`, `cm_discriminant`, `sha`,
`semistable`, `bad_primes`, and `isogeny_degrees`.

Scalar integer ranges with step `1` or `-1` stay compact, including Oscar/Hecke
ranges. Other steps now raise `ArgumentError`; use an explicit vector such as
`in([11, 13, 15])` or `in(collect(11:2:15))` for discrete membership.
"""
function elliptic_curves end

"""
    count_elliptic_curves(conn::LMFDBConnection; limit = Inf, kw...)

Count records in `ec_curvedata` using the same parameters as `elliptic_curves`
and `search`, without constructing Hecke elliptic curves.
"""
function count_elliptic_curves(conn::LMFDBConnection; limit = Inf, kw...)
  return count(conn, "ec_curvedata"; limit, kw...)
end

"""
    elliptic_curves_over_number_fields(conn::LMFDBConnection; limit = Inf, order_by = nothing, kw...)

Search `ec_nfcurves` and convert matching records to Hecke elliptic curves over
number fields. Load Hecke to enable this method. Parameters, `limit`, and
`order_by` are forwarded to `LMFDBLite.search`; the resulting curves preserve
the requested order.

Common parameters include `label`, `field_label`, `degree`, `signature`,
`conductor_label`, `conductor_norm`, `isogeny_class`, `rank`, `analytic_rank`,
`torsion_order`, `torsion_structure`, `cm_discriminant`, and `is_q_curve`.
Use `conductor_norm` for the integer norm of the conductor ideal.
`a_invariants` and `j_invariant` match LMFDB's stored text: comma-separated
rational power-basis coefficients, with semicolons between the five a-invariants.

For example, use `field_label = "2.2.5.1"` to select curves over that field,
or `field_label = in(["2.2.5.1", "2.0.4.1"])` to search over several fields.
Omit `field_label` to search over all number fields in the table. Curves with
the same field label in one result share a Hecke base field, constructed from
the defining polynomial in `nf_fields`. Curves and their base fields carry
their respective `:lmfdb_label` attributes.
"""
function elliptic_curves_over_number_fields end

"""
    count_elliptic_curves_over_number_fields(conn::LMFDBConnection; limit = Inf, kw...)

Count records in `ec_nfcurves` using the same parameters as
`elliptic_curves_over_number_fields`, without requiring Hecke or constructing
curves or number fields. With `limit = n`, return at most `n` matches.
"""
function count_elliptic_curves_over_number_fields(conn::LMFDBConnection; limit = Inf, kw...)
  return count(conn, "ec_nfcurves"; limit, kw...)
end
