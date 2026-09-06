"""
    integer_lattice(db, label)

Retrieve a Hecke integer lattice by its LMFDB label. Load Hecke to enable this method.
"""
function integer_lattice end

"""
    integer_lattices(db; limit = Inf, kw...)

Search `lat_lattices_new` with `LMFDBLite.new_search` and convert the records to
Hecke integer lattices, retaining their `:lmfdb_label` and available
`:lmfdb_genus_label` attributes. Load Hecke to enable this method.

Parameters include `label`, `genus_label`, `rank`, `signature`, `level`,
`class_number`, `is_even`, `discriminant`, `minimum`, `automorphism_group_order`,
`automorphism_group`, `dual_determinant`, `dual_kissing_number`, `gram_matrix`,
`disc_group_invs`, `discriminant_group_exponent`, `kissing_number`,
`festi_veniani_index`, `conway_symbol`, `dual_conway_symbol`, and `scale`.

A signature `(nplus, nminus)` constrains both the rank and the positive index.
Integer parameters accept comparisons, vector/range membership, and combined
bounds with `&`. Labels accept equality and vector membership. Boolean parameters
accept equality. Gram matrices are flattened integer vectors, and group invariants
are integer vectors; both accept equality. `dual_determinant` uses `Float64` inputs
and compares stored numerical values. The database column names `nplus`, `disc`,
and `discriminant_group_invs` are also supported.

Use `LMFDBLite.new_search(db, "lat_lattices_new"; kw...)` for raw records.
"""
function integer_lattices end
