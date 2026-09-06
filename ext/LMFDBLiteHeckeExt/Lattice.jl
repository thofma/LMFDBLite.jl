function _lattice_from_record(record::NamedTuple)
  r = Int(record[:rank])
  G = matrix(ZZ, r, r, record[:gram])
  L = integer_lattice(; gram = G)
  if !ismissing(record[:genus_label]) && !isnothing(record[:genus_label])
    set_attribute!(L, :lmfdb_genus_label => record[:genus_label])
  end
  set_attribute!(L, :lmfdb_label => record[:label])
  return L
end

function Hecke.integer_lattice(conn::LMFDBLite.LMFDBConnection, label::String)
  records = LMFDBLite.search(conn, "lat_lattices_new"; label, limit = 2)
  length(records) <= 1 || error("LMFDB label is not unique")
  isempty(records) && error("label does not exist")
  return _lattice_from_record(only(records))
end

function LMFDBLite.integer_lattices(conn::LMFDBLite.LMFDBConnection; limit = Inf, kw...)
  records = LMFDBLite.search(conn, "lat_lattices_new"; limit, kw...)
  return _lattice_from_record.(records)
end

function LMFDBLite.integer_lattice(conn::LMFDBLite.LMFDBConnection, label::String)
  return Hecke.integer_lattice(conn, label)
end
