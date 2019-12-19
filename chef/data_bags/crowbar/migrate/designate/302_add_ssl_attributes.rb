def upgrade(ta, td, a, d)
  a["ssl"] = ta["ssl"] unless a.key? "ssl"
  return a, d
end

def downgrade(ta, td, a, d)
  a.delete("ssl") unless ta.key? "ssl"
  return a, d
end
