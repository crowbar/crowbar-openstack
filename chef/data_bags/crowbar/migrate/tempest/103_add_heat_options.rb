def upgrade(ta, td, a, d)
  a["heat"] = ta["heat"]
  return a, d
end

def downgrade(ta, td, a, d)
  a.delete("heat")
  return a, d
end
