def upgrade(ta, td, a, d)
  a["ssl"] = ta["ssl"]
  return a, d
end

def downgrade(ta, td, a, d)
  a.delete("ssl")
  return a, d
end
