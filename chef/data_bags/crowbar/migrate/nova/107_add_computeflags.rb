def upgrade(ta, td, a, d)
  a["compute"] = ta["compute"]

  return a, d
end

def downgrade(ta, td, a, d)
  a.delete("compute")

  return a, d
end
