def upgrade(ta, td, a, d)
  a["vcenter"]["ca_file"] = ta["vcenter"]["ca_file"]
  a["vcenter"]["insecure"] = ta["vcenter"]["insecure"]
  return a, d
end

def downgrade(ta, td, a, d)
  a["vcenter"].delete("ca_file")
  a["vcenter"].delete("insecure")
  return a, d
end
