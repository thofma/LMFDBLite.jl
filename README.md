# LMFDBLite.jl

A Julia interface to the LMFDB PostgreSQL database, with optional Hecke support
for constructing number fields, integer lattices, and genera.

```julia
using LMFDBLite
using DBInterface

db = LMFDBLite.LMFDBConnection()
try
    records = LMFDBLite.new_search(db, "nf_fields";
        discriminant = in(-110:3300), class_group = [2, 2],
        ramified = LMFDBLite.includes([2, 3]), degree = 2, limit = 10)
finally
    DBInterface.close!(db)
end
```

`new_search` returns a vector of named tuples. It supports the `nf_fields`,
`lat_lattices_new`, and `lat_genera` tables.

Load Hecke to enable conversion to mathematical objects:

```julia
using LMFDBLite, Hecke
using DBInterface

db = LMFDBLite.LMFDBConnection()
try
    fields = LMFDBLite.number_fields(db; degree = 2, limit = 10)
    lattices = LMFDBLite.integer_lattices(db; rank = 1, limit = 10)
    genera = LMFDBLite.genera(db; rank = 1, limit = 10)
finally
    DBInterface.close!(db)
end
```

The package was previously named `LMFDB`. All public functions now live directly
under `LMFDBLite`: replace `LMFDB.LMFDBLite.new_search` with `LMFDBLite.new_search`
and `LMFDB.number_fields` with `LMFDBLite.number_fields`.

See [test/README.md](test/README.md) for instructions on running the live tests.
