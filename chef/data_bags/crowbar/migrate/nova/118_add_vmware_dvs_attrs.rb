def upgrade(ta, td, a, d)
  a["vcenter"]["dvs_name"] = ta["vcenter"]["dvs_name"]
  a["vcenter"]["dvs_security_groups"] = ta["vcenter"]["dvs_security_groups"]
  return a, d
end

def downgrade(ta, td, a, d)
  a["vcenter"].delete("dvs_name")
  a["vcenter"].delete("dvs_security_groups")
  return a, d
end
