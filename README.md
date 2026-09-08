# LMFDBLite.jl

A Julia interface to the [LMFDB](https://www.lmfdb.org/), with optional
[Hecke](https://github.com/thofma/Hecke.jl) and
[Oscar](https://github.com/oscar-system/Oscar.jl) support for constructing
number fields, elliptic curves over the rationals, integer lattices, and genera.

## Quick example

```julia
using LMFDBLite

conn = lmfdb()
records = LMFDBLite.search(conn, "nf_fields";
    discriminant = in(-110:3300), class_group = [2, 2],
    ramified = includes([2, 3]), degree = 2, limit = 10)
```

The call `lmfdb()` constructs the default `LMFDBConnection` on its first call and
returns that cached connection on subsequent calls. Construct
`LMFDBLite.LMFDBConnection(; host, port, dbname, user, password, schema = "public")`
directly when a custom, independently managed connection is needed. Call `reset!(conn)` to reset the
connection to the [LMFDB](https://www.lmfdb.org/).

Connection values may contain spaces, quotes, or backslashes; pass their literal
values without adding connection-string escaping. The constructor also accepts
`connect_timeout` (initial connection timeout in seconds, default `0` for none)
and libpq's `sslmode`, `sslrootcert`, `sslcert`, and `sslkey`
[TLS options](https://www.postgresql.org/docs/current/libpq-connect.html). TLS
options default to `nothing`, preserving libpq's environment/default settings.
The connection timeout does not limit queries or `reset!`.

The connection reflects tables in the selected schema and uses that same schema
for searches and column metadata, independently of PostgreSQL's `search_path`.
It loads and caches a table's column types on first use, so unsupported types in
unrelated tables do not prevent connecting or searching supported tables.
Search parameter validation still reports missing columns and incorrect types.
Requesting a layout containing an unsupported type raises an error for that
table. Open a new connection after a schema change to refresh reflected tables
and cached layouts; `reset!` only resets communication with the server.

The function `search` returns a vector of named tuples.

The function `LMFDBLite.count(conn, table; limit = Inf, kw...)` accepts the
same parameters as `LMFDBLite.search` and returns the number of matching
records. For example:

```julia
LMFDBLite.count(conn, "nf_fields"; degree = 2, class_number = 1)
```

With `limit = n`, `count` returns a capped count: the smaller of `n` and the
number of matches. The default `limit = Inf` counts every match. This also applies
to `count_number_fields`, `count_elliptic_curves`, `count_integer_lattices`, and
`count_genera`.

## Supported tables

At the moment, the following tables are supported, where "experimental" refers to experimental tables in the LMFDB itself:
- `nf_fields`,
- `ec_curvedata`,
- `lat_lattices_new` (experimental),
- `lat_genera` (experimental),

## Search syntax

Search conditions are passed as keyword values. The operators available for a
particular parameter depend on its type; using an unsupported operator raises an
`ArgumentError` naming the parameter and its supported operators. Invalid operands
also raise `ArgumentError` with the required input form or conversion type.

- Scalar numeric parameters accept a bare value or `==(value)` for equality,
  and the comparisons `<(value)`, `<=(value)`, `>(value)`, and `>=(value)`.
  For example, `degree = ==(4)` and `degree = >=(4)`.
- Use `in([values...])` to match any value in a list. Scalar integer parameters
  also accept inclusive ranges with step `1` or `-1`, such as
  `conductor = in(11:100)`, `in(11:1:100)`, or `in(100:-1:11)`.
- Combine conditions for one parameter with `allof` (logical and) or `anyof`
  (logical or), for example `class_number = allof(>=(2), <=(10))` or
  `class_number = anyof(==(1), ==(2))`. Both accept three or more conditions and
  can be nested: `class_number = allof(>=(2), anyof(==(3), ==(5)))`.
- Text parameters such as `label` accept a string for equality or
  `in(["2.2.5.1", "2.2.8.1"])` for membership.
- Boolean parameters accept `true`, `false`, or explicit equality such as
  `==(true)`.
- Structured parameters—including signatures, class groups, torsion
  structures, and flattened Gram matrices—use exact equality. For example,
  `signature = (2, 0)` and `class_group = [2, 2]`.
- For set-like array parameters, `includes(values)` requires the stored array
  to contain every specified value. For example, `ramified = includes([2, 3])`.
  `issubset(values)` selects stored arrays contained in the specified values.
- For `ramified`, bare vectors and `==(values)` use set equality: `[2, 3]`,
  `[3, 2]`, and `[2, 2, 3]` specify the same ramified primes. An explicit
  `issetequal` predicate is also supported. `ramified = includes(Int[])` imposes
  no required primes; `ramified = Int[]` or `ramified = issubset(Int[])` selects
  empty ramification sets. Class-group equality remains order-sensitive.
- In all cases, `x = val` is shorthand for `x = ==(val)`.

Composition also works for structured parameters, for example
`signature = anyof((2, 0), (0, 1))`. Each signature alternative constrains both
of its database columns together. All branches must use operators and values
supported by that parameter. Different keyword parameters are combined with AND.
With one argument, `allof` and `anyof` return that argument unchanged; with no
arguments, they raise `ArgumentError`.

The existing `&(Function, Function)` overload remains available for combining two
predicates. Use `allof` and `anyof` for longer or mixed combinations; direct `|`
between predicates and chains of `&` are not supported.

All scalar integer parameters, including signed discriminants, and the
number-field `ramified` parameter convert operands using `BigInt(x)`. This
includes values inside comparisons and vectors, and supports Oscar/Hecke
integers (`ZZRingElem`). Integer membership ranges with step `1` or `-1` are
handled using their endpoints, without expanding their elements. This applies
to `Int`, `BigInt`, and Oscar/Hecke ranges on all four tables. Empty unit-step
ranges and empty membership vectors match no records. `ramified` operands must
be explicit vectors. Unsupported operators and invalid operands for these
parameters consistently raise `ArgumentError`, also inside combined conditions.

**Compatibility change for stepped integer ranges:** some parameters previously
accepted ranges such as `class_number = in(1:2:9)` by expanding them into lists.
All scalar integer parameters now reject ranges whose step is neither `1` nor
`-1` with `ArgumentError`, including empty and singleton ranges. This prevents
implicit expansion of large ranges and applies inside `allof` and `anyof` too.
To request discrete values, supply an explicit vector:

```julia
# Previously accepted; now raises ArgumentError:
LMFDBLite.search(conn, "nf_fields"; class_number = in(1:2:9))

# Explicit replacements with the same discrete membership:
LMFDBLite.search(conn, "nf_fields"; class_number = in([1, 3, 5, 7, 9]))
LMFDBLite.search(conn, "nf_fields"; class_number = in(collect(1:2:9)))
```

An explicit vector matches only its listed values; the gaps are not filled in.

## Hecke and Oscar integration

LMFDBLite comes with an optional interface to directly construct native
[Hecke](https://github.com/thofma/Hecke.jl) or
[Oscar](https://github.com/oscar-system/Oscar.jl) objects when querying the
database. The functionality is available after loading either package.

```julia
julia> using LMFDBLite, Hecke

julia> conn = lmfdb()

julia> fields = LMFDBLite.number_fields(conn; degree = 2, class_group = [3, 9], signature = (0, 1), limit = 2)
2-element Vector{AbsSimpleNumField}:
 Number field of degree 2 over QQ
 Number field of degree 2 over QQ

julia> field = number_field(conn, "2.2.5.1")
Number field with defining polynomial x^2 - x - 1
  over rational field

julia> LMFDBLite.elliptic_curves(conn; conductor = in(11:100), rank = 1, limit = 3)
3-element Vector{EllipticCurve{QQFieldElem}}:
 Elliptic curve over QQ with equation y^2 + y = x^3 - x
 Elliptic curve over QQ with equation y^2 + y = x^3 + x^2
 Elliptic curve over QQ with equation y^2 + x*y + y = x^3 - x^2

julia> LMFDBLite.integer_lattices(conn; rank = 3, signature = (3, 0), disc = 1)
1-element Vector{ZZLat}:
 Integer lattice of rank 3 and degree 3

julia> LMFDBLite.genera(conn; rank = 1, limit = 3)
3-element Vector{ZZGenus}:
 Genus symbol: II_(1, 0) 8^1_1 121^-1
 Genus symbol: I_(1, 0) 625^1
 Genus symbol: I_(1, 0) 29^1
```

Use `count_number_fields`, `count_elliptic_curves`, `count_integer_lattices`,
and `count_genera` to count matching records without constructing Hecke
objects.

This package was inspired by the Python
[lmfdb-lite project](https://github.com/roed314/lmfdb-lite).
