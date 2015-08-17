def upgrade ta, td, a, d
  a["postgresql"]["config"] = {}
  a["postgresql"]["config"]["max_connections"] = a["postgresql"]["config_pgtune"]["max_connections"]
  a["postgresql"].delete("config_pgtune")
  return a, d
end

def downgrade ta, td, a, d
  a["postgresql"]["config_pgtune"] = {}
  a["postgresql"]["config_pgtune"]["max_connections"] = a["postgresql"]["config"]["max_connections"]
  a["postgresql"].delete("config")
  return a, d
end
