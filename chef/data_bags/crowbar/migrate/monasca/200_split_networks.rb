def upgrade(ta, td, a, d)
  old_network = a["network"]
  a["network"] = {}
  a["network"]["internal"] = old_network
  a["network"]["clients"] = old_network
  return a, d
end

def downgrade(ta, td, a, d)
  a["network"] = a["network"]["internal"]

  return a, d
end
