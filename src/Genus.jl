"""
    genus(db, label)

Retrieve a Hecke genus of integer lattices by its LMFDB label.
Load Hecke to enable this method.
"""
function genus end

"""
    genera(db; limit = Inf, kw...)

Search `lat_genera` with `LMFDBLite.new_search` and construct Hecke genera from
their stored representative Gram matrices. Attach each genus's `:lmfdb_label`
and cache lattice representatives when the database supplies the complete set.
Load Hecke to enable this method.

Parameters include `label`, `rank`, `signature`, `level`, `class_number`,
`is_even`, `determinant`, `discriminant`, `disc_group_invs`,
`discriminant_group_exponent`, `discriminant_form`, `representative_gram_matrix`,
`mass`, `conway_symbol`, `dual_conway_symbol`, and `scale`.

Signatures are `(nplus, nminus)`. Integer parameters support comparisons and
vector/range membership; labels support equality and vector membership.
Boolean and vector parameters support equality. `mass` supports exact rational
equality, e.g. `mass = 1//2`. Gram matrices are flattened integer vectors.
The database column names `nplus`, `disc`, `det`, `rep`, and
`discriminant_group_invs` are also supported.

Use `LMFDBLite.new_search(db, "lat_genera"; kw...)` for raw records.
"""
function genera end
