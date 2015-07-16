def upgrade ta, td, a, d
  a["vxlan"] = ta["vxlan"]

  return a, d
end

def downgrade ta, td, a, d
  a.delete("vxlan")

  return a, d
end
