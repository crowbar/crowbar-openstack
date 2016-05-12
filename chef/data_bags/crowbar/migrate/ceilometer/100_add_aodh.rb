def upgrade(ta, td, a, d)
  a["aodh"] = {}
  a["aodh"]["service_user"]     = ta["aodh"]["service_user"]
  a["aodh"]["service_password"] = ta["aodh"]["service_password"]
  a["aodh"]["api"]              = ta["aodh"]["api"]
  a["aodh"]["db"]               = ta["aodh"]["db"]
  return a, d
end

def downgrade(ta, td, a, d)
  a.delete("aodh")
  return a, d
end
