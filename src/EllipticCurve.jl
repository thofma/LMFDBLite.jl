"""
    elliptic_curves(conn::LMFDBConnection; limit = Inf, kw...)

Search the `ec_curvedata` table and convert matching records to Hecke elliptic
curves over the rationals. Load Hecke to enable this method. Parameters and
`limit` are forwarded to `LMFDBLite.search`.

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
