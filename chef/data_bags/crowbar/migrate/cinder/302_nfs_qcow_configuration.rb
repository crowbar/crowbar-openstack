def upgrade(tattr, tdep, attr, dep)
  attr["volume_defaults"]["nfs"]["nfs_qcow2_volumes"] =
    tattr["volume_defaults"]["nfs"]["nfs_qcow2_volumes"]

  attr["volumes"].each do |volume|
    next if volume["backend_driver"] != "nfs"
    attr["volume_defaults"]["nfs"]["nfs_qcow2_volumes"] = false
  end

  return attr, dep
end

def downgrade(tattr, tdep, attr, deps)
  attr["volume_defaults"]["nfs"].delete("nfs_qcow2_volumes")
  return attr, dep
end
