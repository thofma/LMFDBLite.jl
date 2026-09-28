The default suite runs without a database connection. `core.jl` checks the raw
query core; the Tachikoma form tests check the built-in UI, and `hecke.jl` checks
the optional Hecke extension. Dependency installation may require network access,
but the tests themselves do not contact PostgreSQL.
CI runs these offline tests separately from local PostgreSQL and public-mirror
integration jobs.

Opt-in connection tests verify that `lmfdb()` constructs its default connection
lazily, returns the same object across calls and tasks, invalidates the cache
when closed, and reconstructs it on demand. Type-specific count functions are
checked against their corresponding raw searches.

The test runner first checks that loading LMFDBLite makes `ui()` available
without explicitly loading Tachikoma, while Hecke remains unloaded. It then
runs offline parsing, form interaction, and submission tests for all five
supported databases.
Integer parsing tests cover Tryparse expressions, power-based bounds such as
`0..2^5`, signed power expressions, exact large literals, compact
BigInt ranges, and malformed expressions.
Headless tests exercise the LMFDB landing page, every database search form,
selection with Enter, returning
to the menu while preserving filters, wide/narrow layouts, resizing, focus,
selectors, validation, reset, cancellation, and mouse actions. Submission tests use private test doubles
to verify that connection acquisition and search happen exactly once in a
background task while the form and spinner remain visible. They exercise success,
failure, empty results, raw-row browsing, conversion after terminal restoration,
detail scrolling, and keyboard and mouse return actions. Pure form tests
also check per-database Search and Count dispatch, total counts independent of the result limit, zero
matches, and invalid filters without opening a connection. These tests
do not require Hecke; the public launcher explains that Hecke or Oscar must be loaded.
The opt-in number-field live tests submit a bounded quadratic-field search using
the integration suite's connection and check the returned Hecke field.

The runner then loads Hecke
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

Integer range tests cover every scalar integer parameter on all supported tables,
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

To include read-only integration queries, set `LMFDB_TEST_LIVE=true`. These use
the public mirror by default (`devmirror.lmfdb.xyz:5432`). Set any of `LMFDB_HOST`,
`LMFDB_PORT`, `LMFDB_DBNAME`, `LMFDB_USER`, `LMFDB_PASSWORD`, and `LMFDB_SCHEMA` to
use another database. Overrides alone do not enable integration tests.
Connection failures fail an enabled integration run.

The cached-default smoke test is a separate opt-in:
`LMFDB_TEST_PUBLIC_DEFAULT=true`. It deliberately tests bare `lmfdb()` against
the public mirror and does not use the connection overrides. Keep it unset when
testing a local database. To run both public integration groups:

```sh
LMFDB_TEST_LIVE=true LMFDB_TEST_PUBLIC_DEFAULT=true julia --project=. -e 'using Pkg; Pkg.test()'
```

The CI matrix starts at the minimum supported Julia version, 1.11. Each version
runs both the core and Hecke tests through the normal `Pkg.test()` target.

The metadata regression tests create a temporary PostgreSQL test database
and check unrelated unsupported types, same-named tables in different schemas,
an overridden `search_path`, quoted schema names, lazy caching, type mappings,
and missing/mistyped search columns. The database server listens only on a Unix
socket in its temporary directory. The tests shut down the server and remove
its data afterwards. They do not use or modify the public mirror or the database
selected by `LMFDB_*`.

To include the temporary database tests in the full suite, set
`LMFDB_POSTGRES_BIN` to a directory containing PostgreSQL's `initdb` and `pg_ctl`.
You can also run them independently:

```sh
LMFDB_POSTGRES_BIN=/path/to/postgresql/bin julia --project=. test/metadata_postgresql.jl
```

Without this setting, the temporary database tests are not run. Type mapping
tests always run; live metadata checks run only with `LMFDB_TEST_LIVE=true`.

Connection-string tests use libpq's parser without connecting and verify literal
values for all constructor fields and TLS options, including whitespace, quotes,
backslashes, Unicode, and empty strings. They also check that one field cannot
introduce a second option, and that NUL characters and invalid timeouts are
rejected before connecting.

Input-validation tests cover text, Boolean, floating-point, structured integer
array, and rational parameters on all supported tables, including aliases. Invalid
operands and operators must produce `ArgumentError` naming the parameter, also
inside mixed conditions. Separate schema/invariant tests still expect internal
errors for malformed declarations; those are not user-input failures.

Root discriminant tests cover scalar values, comparisons, list membership, and
combined bounds. Equality and membership compare the stored floating-point `rd`
values exactly, which may differ from root discriminants computed in Julia.

Additional number field tests cover labels, signatures, class and narrow class
invariants, relative class numbers, indices, Galois root discriminants, regulators,
and the cyclic, abelian, solvable, CM, and minimal sibling flags. They compare
filtered results with raw database records, including integer ranges, empty
results, missing relative class numbers, and Hecke conversion with combined filters.

All record retrieval uses `search`, which supports `nf_fields`, `ec_curvedata`,
`ec_nfcurves`, `lat_lattices_new`, and `lat_genera`. The previous search implementation and
lattice validation framework have been removed. `count` shares the parameter
validation and query construction used by `search`.

Lattice and genus tests check parameter schemas, signatures, numeric and array
filters, rational mass equality, counts, limits, empty results, label lookups,
Hecke conversion, and retrieval of genus representatives. Incomplete representative
sets are not cached as complete sets. Use `search` for raw records and the
Hecke extension methods for mathematical objects; there is no separate `raw` mode.

Elliptic-curve tests check the `ec_curvedata` parameter schema, scalar and array
filters, signed discriminants, counts, and conversion to Hecke elliptic curves.

Number field elliptic-curve tests cover `ec_nfcurves`, including its JSON
signatures and torsion structures, integer arrays, and power-basis coefficient
strings. Offline tests construct quadratic and cubic curves, check exact
fractions and large coefficients, and verify that a result batch loads each
distinct base field once and shares it between curves. The temporary database
tests exercise searches and counts without Hecke. Live tests validate all
declared column types, filters, counts, limits, full-label lookup, and conversion.

Ordering tests validate public keys, aliases, directions, unsupported structured
values, and required column types without a database. Temporary PostgreSQL tests
use shuffled rows with ties and missing values to check ascending and descending
orders, multiple keys, signed discriminants, ordering before limits, and the
automatic `id` tie-breaker. They also check that unordered queries and counts
omit `ORDER BY`. Live tests compare limited searches and Hecke objects with an
independently sorted reference set.
