These tests make read-only queries against the live LMFDB PostgreSQL database
used by `LMFDBLite.lmfdb()` (`devmirror.lmfdb.xyz:5432` by default).
They require network access; connection failures fail the test run.

Connection tests verify that `lmfdb()` constructs its default connection
lazily, returns the same object across calls and tasks, invalidates the cache
when closed, and reconstructs it on demand. Type-specific count functions are
checked against their corresponding raw searches.

The test runner first checks that LMFDBLite loads without Hecke, then loads Hecke
to activate `LMFDBLiteHeckeExt` and test conversion to number fields, elliptic
curves, integer lattices, and genera. Hecke is a test dependency and an optional
dependency of LMFDBLite. In a user session, load both packages with
`using LMFDBLite, Hecke` before calling conversion functions; raw searches
through `LMFDBLite.search` do not require Hecke.

Parameter consistency tests check every declared PostgreSQL column and type
against the live connection metadata, including both columns used by signature
and discriminant. Local tests simulate missing columns, changed types, and
incorrectly declared or generated conditions; the database itself is never modified.
These checks distinguish `class_group` (`jsonb`) from `narrow_class_group`
(`bigint[]`) while requiring their Julia input types to agree.

Signed-discriminant tests run without a database before the live tests. They
exercise both table registries, recursive conditions, conversion through
`BigInt(x)`, empty membership, integer extrema, and bounded SQL size for large
ranges. After Hecke loads, the same input tests also cover `ZZRingElem` values
and ranges. Live tests compare filtered records with small reference sets of
number fields and elliptic curves containing both signs of discriminant.

You can run the complete declaration check on an existing connection with
`LMFDBLite.check_number_field_parameters(conn)`, or use
`LMFDBLite.check_search_parameters(conn, table)` for any supported table.
Each `search` call checks
the parameters it uses before issuing the query. The checks use metadata cached
when the connection was opened, so reconnect to check a changed database schema.

Run from the package directory:

```sh
julia --project=. -e 'using Pkg; Pkg.test()'
```

To use another LMFDB database, set any of `LMFDB_HOST`, `LMFDB_PORT`,
`LMFDB_DBNAME`, `LMFDB_USER`, and `LMFDB_PASSWORD` before running the tests.

Root discriminant tests cover scalar values, comparisons, list membership, and
combined bounds. Equality and membership compare the stored floating-point `rd`
values exactly, which may differ from root discriminants computed in Julia.

Additional number field tests cover labels, signatures, class and narrow class
invariants, relative class numbers, indices, Galois root discriminants, regulators,
and the cyclic, abelian, solvable, CM, and minimal sibling flags. They compare
filtered results with raw database records, including integer ranges, empty
results, missing relative class numbers, and Hecke conversion with combined filters.

All record retrieval uses `search`, which supports `nf_fields`, `ec_curvedata`,
`lat_lattices_new`, and `lat_genera`. The previous search implementation and
lattice validation framework have been removed. `count` shares the parameter
validation and query construction used by `search`.

Lattice and genus tests check parameter schemas, signatures, numeric and array
filters, rational mass equality, counts, limits, empty results, label lookups,
Hecke conversion, and retrieval of genus representatives. Incomplete representative
sets are not cached as complete sets. Use `search` for raw records and the
Hecke extension methods for mathematical objects; there is no separate `raw` mode.

Elliptic-curve tests check the `ec_curvedata` parameter schema, scalar and array
filters, signed discriminants, counts, and conversion to Hecke elliptic curves.
