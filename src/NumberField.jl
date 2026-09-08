"""
    number_fields(conn::LMFDBConnection; limit = Inf, kw...)

Search number fields with `LMFDBLite.search` and convert each record to a
Hecke number field with its `:lmfdb_label` attribute. Load Hecke with `using Hecke`
to enable this method. Search parameters and `limit` are forwarded to `search`.

Supported parameters include:

- `label`, `galois_group`: a string, `==(value)`, or `in([values...])`.
  Galois groups use transitive labels such as `"4T2"`.
- `signature`: `(r1, r2)` or `[r1, r2]`, optionally wrapped in `==`, where
  `r1` counts real embeddings and `r2` counts pairs of complex embeddings.
  This constrains the degree to `r1 + 2r2` as well as the signature.
  Use `anyof((2, 0), (0, 1))` to accept either of two signatures.
- `class_number`, `narrow_class_number`, `relative_class_number`, `index`:
  an integer, a comparison (`==`, `<`, `<=`, `>`, `>=`), or `in` with an
  integer vector or range. Combine bounds with `allof`, e.g. `allof(>=(2), <=(10))`.
- `class_group`, `narrow_class_group`: a vector of invariant factors in
  increasing divisibility order, optionally wrapped in `==`. Use `Int[]`
  for the trivial group.
- `root_discriminant`, `galois_root_discriminant`, `regulator`: real values,
  comparisons, or list membership. Inputs are converted to `Float64`;
  equality compares with stored values, which may be rounded.
- `is_galois`, `is_cyclic`, `is_abelian`, `is_solvable`, `is_cm`,
  `is_minimal_sibling`: `true`, `false`, or an explicit equality.
- `degree`, `discriminant`, `ramified`, `ramified_prime_count` are also available.

Conditions for one parameter can be combined with `allof` (AND) and `anyof` (OR),
including nested combinations. Each branch must use a supported operator and value.

For example, search for real quadratic fields with class number one but
narrow class number two:

```julia
LMFDBLite.number_fields(conn; signature = (2, 0), class_number = 1,
                    narrow_class_number = 2, limit = 10)
```
"""
function number_fields end

"""
    count_number_fields(conn::LMFDBConnection; limit = Inf, kw...)

Count records in `nf_fields` using the same parameters as `number_fields` and
`search` without constructing Hecke number fields.
"""
function count_number_fields(conn::LMFDBConnection; limit = Inf, kw...)
  return count(conn, "nf_fields"; limit, kw...)
end
