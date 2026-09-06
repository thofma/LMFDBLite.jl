# LMFDBLite.jl

A Julia interface to the LMFDB PostgreSQL database, with optional Hecke support
for constructing number fields, elliptic curves over the rationals, integer
lattices, and genera.

```julia
using LMFDBLite

conn = LMFDBLite.lmfdb()
records = LMFDBLite.search(conn, "nf_fields";
    discriminant = in(-110:3300), class_group = [2, 2],
    ramified = LMFDBLite.includes([2, 3]), degree = 2, limit = 10)
```

`lmfdb()` constructs the default `LMFDBConnection` on its first call and
returns that cached connection on subsequent calls. Construct
`LMFDBConnection(; host, port, dbname, user, password)` directly when a custom,
independently managed connection is needed.

`search` returns a vector of named tuples. It supports the `nf_fields`,
`ec_curvedata`, `lat_lattices_new`, and `lat_genera` tables.

Load Hecke to enable conversion to mathematical objects:

```julia
using LMFDBLite, Hecke

conn = LMFDBLite.lmfdb()
fields = LMFDBLite.number_fields(conn; degree = 2, limit = 10)
field = Hecke.number_field(conn, "2.2.5.1")
curves = LMFDBLite.elliptic_curves(conn; conductor = in(11:100), rank = 1,
    limit = 10)
lattices = LMFDBLite.integer_lattices(conn; rank = 1, limit = 10)
genera = LMFDBLite.genera(conn; rank = 1, limit = 10)
```

Use `count_number_fields`, `count_elliptic_curves`,
`count_integer_lattices`, and `count_genera` to count matching records without
constructing Hecke objects.

The package was previously named `LMFDB`. All public functions now live directly
under `LMFDBLite`: replace `LMFDB.LMFDBLite.search` with `LMFDBLite.search`
and `LMFDB.number_fields` with `LMFDBLite.number_fields`.

See [test/README.md](test/README.md) for instructions on running the live tests.
