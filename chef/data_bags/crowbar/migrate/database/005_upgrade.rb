def upgrade(ta, td, a, d)
  a["upgrade"] = ta["upgrade"]
  return a, d
end

def downgrade(ta, td, a, d)
  a.delete("upgrade")
  return a, d
end
