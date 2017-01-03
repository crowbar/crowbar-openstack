def upgrade(ta, td, a, d)
  a["f5"] = ta["f5"]
  return a, d
end

def downgrade(ta, td, a, d)
  a.delete("f5")
  return a, d
end
