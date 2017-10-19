def upgrade(ta, td, a, d)
  a["mysql"]["ha"] = ta["mysql"]["ha"]
  return a, d
end

def downgrade(ta, td, a, d)
  a["mysql"].delete("ha")
  return a, d
end
