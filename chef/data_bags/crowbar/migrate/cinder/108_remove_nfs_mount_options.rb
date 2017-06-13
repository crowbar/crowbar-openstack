def upgrade(ta, td, a, d)
  if a["volume_defaults"]["nfs"].key? "nfs_mount_options"
    a["volume_defaults"]["nfs"].delete("nfs_mount_options")
  end
  a["volumes"].each do |volume|
    next if volume["backend_driver"] != "nfs"
    if volume["nfs"].key? "nfs_mount_options"
      volume["nfs"].delete("nfs_mount_options")
    end
  end
  return a, d
end

def downgrade(ta, td, a, d)
  a["volume_defaults"]["nfs"]["nfs_mount_options"] = ""
  a["volumes"].each do |volume|
    volume["nfs"]["nfs_mount_options"] = "" if volume["backend_driver"] == "nfs"
  end
  return a, d
end
