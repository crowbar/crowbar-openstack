def upgrade(ta, td, a, d)
  a["vmware_dvs"] = {}
  a["vmware_dvs"]["host"] = ta["vmware"]["host"]
  a["vmware_dvs"]["port"] = ta["vmware"]["port"]
  a["vmware_dvs"]["user"] = ta["vmware"]["user"]
  a["vmware_dvs"]["password"] = ta["vmware"]["password"]
  a["vmware_dvs"]["ca_file"] = ta["vmware"]["ca_file"]
  a["vmware_dvs"]["insecure"] = ta["vmware"]["insecure"]
  a["vmware_dvs"]["dvs_name"] = ta["vmware"]["dvs_name"]
  unless a["vmware"].nil?
    a["vmware_nsx"] = {}
    a["vmware_nsx"]["user"] = a["vmware"]["user"]
    a["vmware_nsx"]["password"] = a["vmware"]["password"]
    a["vmware_nsx"]["port"] = a["vmware"]["port"]
    a["vmware_nsx"]["controllers"] = a["vmware"]["controllers"]
    a["vmware_nsx"]["tz_uuid"] = a["vmware"]["tz_uuid"]
    a["vmware_nsx"]["l3_gw_uuid"] = a["vmware"]["l3_gw_uuid"]
    a.delete("vmware")
  end
  return a, d
end

def downgrade(ta, td, a, d)
  a["vmware"] = {}
  a["vmware"]["user"] = ta["vmware"]["user"]
  a["vmware"]["password"] = ta["vmware"]["password"]
  a["vmware"]["port"] = ta["vmware"]["port"]
  a["vmware"]["controllers"] = ta["vmware"]["controllers"]
  a["vmware"]["tz_uuid"] = ta["vmware"]["tz_uuid"]
  a["vmware"]["l3_gw_uuid"] = ta["vmware"]["l3_gw_uuid"]
  unless a["vmware_nsx"].nil?
    a["vmware"]["user"] = a["vmware_nsx"]["user"]
    a["vmware"]["password"] = a["vmware_nsx"]["password"]
    a["vmware"]["port"] = a["vmware_nsx"]["port"]
    a["vmware"]["controllers"] = a["vmware_nsx"]["controllers"]
    a["vmware"]["tz_uuid"] = a["vmware_nsx"]["tz_uuid"]
    a["vmware"]["l3_gw_uuid"] = a["vmware_nsx"]["l3_gw_uuid"]
    a.delete("vmware_nsx")
  end
  a["vmware_dvs"].nil? || a.delete("vmware_dvs")
  return a, d
end
