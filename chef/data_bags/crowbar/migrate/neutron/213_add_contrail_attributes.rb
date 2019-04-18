def upgrade ta, td, a, d
  a["contrail"] = {}
  a["contrail"]["api_server_ip"] = ta["contrail"]["api_server_ip"]
  a["contrail"]["api_server_port"] = ta["contrail"]["api_server_port"]
  a["contrail"]["analytics_server_ip"] = ta["contrail"]["analytics_server_ip"]
  a["contrail"]["analytics_server_port"] = ta["contrail"]["analytics_server_port"]
  return a, d
end

def downgrade ta, td, a, d
  a.delete("contrail")
  return a, d
end
