def upgrade(ta, td, a, d)
  a.delete("verbose")
  a["dns_domain"] = a["dhcp_domain"]
  a.delete("dhcp_domain")
  return a, d
end

def downgrade(ta, td, a, d)
  a["verbose"] = ta["verbose"]
  a["dhcp_domain"] = a["dns_domain"]
  a.delete("dns_domain")
  return a, d
end
