"""
    count_genera(conn::LMFDBConnection; limit = Inf, kw...)

Count records in `lat_genera` using the same parameters as `integer_genera` and
`search`, without loading Hecke.
"""
function count_genera(conn::LMFDBConnection; limit = Inf, kw...)
  return count(conn, "lat_genera"; limit, kw...)
end
