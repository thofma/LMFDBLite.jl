function _lattice_from_record(record::NamedTuple)
  r = Int(record[:rank])
  G = matrix(ZZ, r, r, record[:gram])
  L = integer_lattice(;gram = G)
  if !ismissing(record[:genus_label]) && !isnothing(record[:genus_label])
    set_attribute!(L, :lmfdb_genus_label => record[:genus_label])
  end
  set_attribute!(L, :lmfdb_label => record[:label])
  return L
end

function Hecke.integer_lattice(db::LMFDBLite.LMFDBConnection, label::String)
  res = LMFDBLite.new_search(db, "lat_lattices_new"; label, limit = 2)
  @assert length(res) <= 1
  if length(res) == 0
    error("label does not exist")
  end
  return _lattice_from_record(res[1])
end

function LMFDBLite.integer_lattices(db::LMFDBLite.LMFDBConnection; limit = Inf, kw...)
  res = LMFDBLite.new_search(db, "lat_lattices_new"; limit, kw...)
  return _lattice_from_record.(res)
end

function LMFDBLite.integer_lattice(db::LMFDBLite.LMFDBConnection, label::String)
  return Hecke.integer_lattice(db, label)
end
