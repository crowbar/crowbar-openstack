def upgrade(ta, td, a, d)
  a["api"]["timeout"] = ta["api"]["timeout"]
  return a, d
end

def downgrade(ta, td, a, d)
  a["api"].delete("timeout")
  return a, d
end
