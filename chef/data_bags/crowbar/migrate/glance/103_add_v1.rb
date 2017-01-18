def upgrade(ta, td, a, d)
  a["enable_v1"] = true
  return a, d
end

def downgrade(ta, td, a, d)
  a.delete("enable_v1")
  return a, d
end
