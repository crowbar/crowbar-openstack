def upgrade(ta, td, a, d)
  a["mysql"].key?("ha") || a["mysql"]["ha"] = ta["mysql"]["ha"]
  return a, d
end

def downgrade(ta, td, a, d)
  a["mysql"].delete("ha")
  return a, d
end
