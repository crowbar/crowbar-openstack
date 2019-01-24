def upgrade(ta, td, a, d)
  a["mysql"]["ssl"] = ta["mysql"]["ssl"] unless a["mysql"].key? "ssl"
  return a, d
end

def downgrade(ta, td, a, d)
  a["mysql"].delete("ssl") unless ta["mysql"].key? "ssl"
  return a, d
end
