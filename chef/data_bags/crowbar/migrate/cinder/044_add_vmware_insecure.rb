def upgrade(ta, td, a, d)
  a["volume_defaults"]["vmware"]["ca_file"] = ta["volume_defaults"]["vmware"]["ca_file"]
  a["volume_defaults"]["vmware"]["insecure"] = ta["volume_defaults"]["vmware"]["insecure"]
  a["volumes"].each do |volume|
    next if volume["backend_driver"] != "vmware"
    volume["vmware"]["ca_file"] = ta["volume_defaults"]["vmware"]["ca_file"]
    volume["vmware"]["insecure"] = ta["volume_defaults"]["vmware"]["insecure"]
  end
  return a, d
end

def downgrade(ta, td, a, d)
  a["volume_defaults"]["vmware"].delete("ca_file")
  a["volume_defaults"]["vmware"].delete("insecure")
  a["volumes"].each do |volume|
    next if volume["backend_driver"] != "vmware"
    volume["vmware"].delete("ca_file")
    volume["vmware"].delete("insecure")
  end
  return a, d
end
