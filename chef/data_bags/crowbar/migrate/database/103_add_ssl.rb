def upgrade(ta, td, a, d)
  a["mysql"]["ssl"] = ta["mysql"]["ssl"]
  return a, d
end

def downgrade(ta, td, a, d)
  a["mysql"].delete("ssl")
  return a, d
end
