def upgrade(ta, td, a, d)
  a["volume_defaults"]["vmware"]["cluster_name"] = ta["volume_defaults"]["vmware"]["cluster_name"]
  a["volumes"].each do |volume|
    next if volume["backend_driver"] != "vmware"
    volume["vmware"]["cluster_name"] = ta["volume_defaults"]["vmware"]["cluster_name"]
  end

  return a, d
end

def downgrade(ta, td, a, d)
  a["volume_defaults"]["vmware"].delete("cluster_name")
  a["volumes"].each do |volume|
    next if volume["backend_driver"] != "vmware"
    volume["vmware"].delete("cluster_name")
  end
  return a, d
end
