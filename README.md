# LMFDBLite.jl

A Julia interface to the LMFDB PostgreSQL database, with optional Hecke support
for constructing number fields, elliptic curves over the rationals, integer
lattices, and genera.

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
`LMFDBConnection(; host, port, dbname, user, password)` directly when a custom,
independently managed connection is needed.

The function `search` returns a vector of named tuples.

The function `LMFDBLite.count(conn, table; limit = Inf, kw...)` accepts the
same parameters as `LMFDBLite.search` and returns the number of matching
records. For example:

```julia
LMFDBLite.count(conn, "nf_fields"; degree = 2, class_number = 1)
```

## Supported tables

At the moment, the following tables are supported, where "experimental" refers to experimental tablesi in the LMFDB itself:
- `nf_fields`,
- `ec_curvedata`,
- `lat_lattices_new` (experimental),
- `lat_genera` (experimental),

## Search syntax

Search conditions are passed as keyword values. The operators available for a
particular parameter depend on its type; using an unsupported operator raises an
error.

- Scalar numeric parameters accept a bare value or `==(value)` for equality,
  and the comparisons `<(value)`, `<=(value)`, `>(value)`, and `>=(value)`.
  For example, `degree = ==(4)` and `degree = >=(4)`.
- Use `in([values...])` to match any value in a list. Integer parameters also
  accept an inclusive unit range, such as `conductor = in(11:100)`.
- Combine conditions with `&` (logical and) or `|` (logical or), for example
  `class_number = >=(2) & <=(10)`.
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
- In all cases, `x = val` is shorthand for `x = ==(val)`.

## Oscar and Hecke integration

Load Hecke or Oscar to enable conversion to native mathematical objects:

```julia
using LMFDBLite, Hecke

conn = lmfdb()
fields = LMFDBLite.number_fields(conn; degree = 2, limit = 10)
field = number_field(conn, "2.2.5.1")
curves = LMFDBLite.elliptic_curves(conn; conductor = in(11:100), rank = 1,
    limit = 10)
lattices = LMFDBLite.integer_lattices(conn; rank = 1, limit = 10)
genera = LMFDBLite.genera(conn; rank = 1, limit = 10)
```

Use `count_number_fields`, `count_elliptic_curves`,
`count_integer_lattices`, and `count_genera` to count matching records without
constructing Hecke objects.
