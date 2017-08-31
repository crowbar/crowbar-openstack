def upgrade(ta, td, a, d)
  unless a["volume_defaults"]["nfs"].key? "nfs_snapshot"
    a["volume_defaults"]["nfs"]["nfs_snapshot"] = ta["volume_defaults"]["nfs"]["nfs_snapshot"]

    a["volumes"].each do |volume|
      next if volume["backend_driver"] != "nfs"
      volume["nfs"]["nfs_snapshot"] = ta["volume_defaults"]["nfs"]["nfs_snapshot"]
    end
  end

  return a, d
end

def downgrade(ta, td, a, d)
  if ta["volume_defaults"]["nfs"].key? "nfs_snapshot"
    a["volume_defaults"]["nfs"].delete("nfs_snapshot")

    a["volumes"].each do |volume|
      next if volume["backend_driver"] != "nfs"
      volume["nfs"].delete("nfs_snapshot")
    end
  end

  return a, d
end
