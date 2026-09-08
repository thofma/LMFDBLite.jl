The default suite makes read-only queries against the live LMFDB PostgreSQL database
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
exercise the parameter definitions for both tables, recursive conditions,
conversion through `BigInt(x)`, empty membership, integer extrema, and bounded SQL
size for large ranges. After Hecke loads, the same input tests also cover
`ZZRingElem` values and ranges. Live tests compare filtered records with small
reference sets of number fields and elliptic curves containing both signs of
discriminant.

The degree, ramified-prime count, and ramified-prime set tests cover their
declared operators, nested validation, exact conversion, compact ranges, and
set equality with reordered or repeated primes. They distinguish empty scalar
membership from empty set inclusion and equality, and check that class-group
equality retains its order. Inputs include `Int`, `Int32`, `BigInt`, a custom
convertible type, and (after loading Hecke) `ZZRingElem`. Live tests compare
against a small reference set that includes the rational field with no ramified
primes.

Boolean composition tests use the public `allof` and `anyof` functions for
three-condition and nested combinations across all supported tables. They check
single-argument and empty calls, invalid nested operators, and both columns of
each signature alternative against independent reference signatures. Existing
integer, discriminant, and ramification tests also use this syntax, including
`ZZRingElem` inputs after Hecke loads. Live tests compare composed signature
queries with independently filtered number-field, lattice, and genus records.

Integer range tests cover every scalar integer parameter on all four tables,
including aliases, signed discriminants, and Oscar/Hecke ranges. Ascending,
explicit-step, and descending unit ranges must produce the same bounded SQL.
Small reference sets check empty ranges and discrete vector membership. Ranges
with any other step must raise `ArgumentError`, even when empty, singleton, or
nested inside a condition. This replaces the previous implicit expansion of
stepped ranges on some parameters; the tests check the documented migration
from `in(1:2:9)` to `in([1, 3, 5, 7, 9])` or `in(collect(1:2:9))`.
Live tests compare unit-range filters with independently filtered records.

You can run the complete declaration check on an existing connection with
`LMFDBLite.check_number_field_parameters(conn)`, or use
`LMFDBLite.check_search_parameters(conn, table)` for any supported table.
Each `search` call checks
the parameters it uses before issuing the query. The checks fetch a table's
metadata on first use and cache it for the lifetime of the connection, so
reconnect to check a changed database schema. Live tests also check that layouts
start unloaded and are reused after the first request.

Run from the package directory:

```sh
julia --project=. -e 'using Pkg; Pkg.test()'
```

To use another LMFDB database, set any of `LMFDB_HOST`, `LMFDB_PORT`,
`LMFDB_DBNAME`, `LMFDB_USER`, `LMFDB_PASSWORD`, and `LMFDB_SCHEMA` before running the tests.

The metadata regression fixture creates a private temporary PostgreSQL cluster
and tests unrelated unsupported types, same-named tables in different schemas,
an overridden `search_path`, quoted schema names, lazy caching, type mappings,
and missing/mistyped search columns. It listens only on a Unix socket in its
temporary directory and shuts down and removes the cluster afterwards. It does
not use or modify the public mirror or the database selected by `LMFDB_*`.

To include this fixture in the full suite, set `LMFDB_POSTGRES_BIN` to a directory
containing PostgreSQL's `initdb` and `pg_ctl`. You can also run it independently:

```sh
LMFDB_POSTGRES_BIN=/path/to/postgresql/bin julia --project=. test/metadata_postgresql.jl
```

Without this setting, the fixture is not run; the type mapping and live metadata
checks still run as part of the normal suite.

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
