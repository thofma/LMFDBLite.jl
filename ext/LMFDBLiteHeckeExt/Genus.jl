function _genera_from_records(db, records::Vector{<:NamedTuple})
  res = ZZGenus[]
  isempty(records) && return res
  genus_labels = [r[:label] for r in records]
  reps = integer_lattices(db; genus_label = in(genus_labels))
  for record in records
    label = record[:label]
    repsG = filter(r -> get_attribute(r, :lmfdb_genus_label) == label, reps)
    r = Int(record[:rank])
    rep = integer_lattice(; gram = matrix(ZZ, r, r, record[:rep]))
    G = Hecke.genus(rep)
    set_attribute!(G, :lmfdb_label => label)
    # Cache representatives only when the database contains the complete set.
    if !ismissing(record[:class_number]) && length(repsG) == record[:class_number] && !isempty(repsG)
      set_attribute!(G, :representatives => repsG)
    end
    push!(res, G)
  end
  return res
end

function _genus_from_record(db, record::NamedTuple)
  return only(_genera_from_records(db, [record]))
end

function LMFDBLite.genus(db::LMFDBLite.LMFDBConnection, label::String)
  res = LMFDBLite.new_search(db, "lat_genera"; label, limit = 2)
  @assert length(res) <= 1
  if length(res) == 0
    error("label does not exist")
  end
  return _genus_from_record(db, res[1])
end

function LMFDBLite.genera(db::LMFDBLite.LMFDBConnection; limit = Inf, kw...)
  res = LMFDBLite.new_search(db, "lat_genera"; limit, kw...)
  return _genera_from_records(db, res)
end
