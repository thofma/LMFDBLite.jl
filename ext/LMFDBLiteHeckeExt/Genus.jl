function _genus_from_record(record::NamedTuple, genus_representatives::Vector{ZZLat})
  rank = Int(record[:rank])
  representative = integer_lattice(; gram = matrix(ZZ, rank, rank, record[:rep]))
  G = Hecke.genus(representative)
  set_attribute!(G, :lmfdb_label => record[:label])
  if !ismissing(record[:class_number]) &&
     length(genus_representatives) == record[:class_number] &&
     !isempty(genus_representatives)
    # Hecke 0.40.5 moved the representative cache from an attribute to a field.
    if hasfield(typeof(G), :_representatives)
      G._representatives = genus_representatives
    else
      set_attribute!(G, :representatives => genus_representatives)
    end
  end
  return G
end

function _integer_genera_from_records(conn::LMFDBLite.LMFDBConnection, records::Vector{<:NamedTuple})
  result = ZZGenus[]
  isempty(records) && return result
  genus_labels = [record[:label] for record in records]
  representatives = integer_lattices(conn; genus_label = in(genus_labels))
  for record in records
    label = record[:label]
    genus_representatives = filter(
      representative -> get_attribute(representative, :lmfdb_genus_label) == label,
      representatives,
    )
    push!(result, _genus_from_record(record, genus_representatives))
  end
  return result
end

function _genus_from_record(conn::LMFDBLite.LMFDBConnection, record::NamedTuple)
  return only(_integer_genera_from_records(conn, [record]))
end

"""
    genus(conn::LMFDBConnection, label::String)

Return the genus of integer lattices with the given LMFDB label and attach the
label as its `:lmfdb_label` attribute.
"""
function Hecke.genus(conn::LMFDBLite.LMFDBConnection, label::String)
  records = LMFDBLite.search(conn, "lat_genera"; label, limit = 2)
  length(records) <= 1 || error("LMFDB label is not unique")
  isempty(records) && error("label does not exist")
  return _genus_from_record(conn, only(records))
end

function Hecke.integer_genera(conn::LMFDBLite.LMFDBConnection; limit = Inf, kw...)
  records = LMFDBLite.search(conn, "lat_genera"; limit, kw...)
  return _integer_genera_from_records(conn, records)
end
