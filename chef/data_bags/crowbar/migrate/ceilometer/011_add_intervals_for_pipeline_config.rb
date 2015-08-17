def upgrade ta, td, a, d
  a["disk_interval"] = a["meters_interval"]
  a["network_interval"] = a["meters_interval"]
  return a, d
end

def downgrade ta, td, a, d
  a.delete("disk_interval")
  a.delete("network_interval")
  return a, d
end
