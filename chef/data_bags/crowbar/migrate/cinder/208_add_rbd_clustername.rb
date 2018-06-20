def upgrade(ta, td, a, d)
  a["volume_defaults"]["rbd"]["cluster_name"] = \
    ta["volume_defaults"]["rbd"]["cluster_name"]

  a["volumes"].each do |volume|
    next if volume["backend_driver"] != "rbd"
    volume["rbd"]["cluster_name"] = \
      ta["volume_defaults"]["rbd"]["cluster_name"]
  end
  return a, d
end

def downgrade(ta, td, a, d)
  a["volume_defaults"]["rbd"].delete "cluster_name"

  a["volumes"].each do |volume|
    next if volume["backend_driver"] != "rbd"
    volume["rbd"].delete("cluster_name")
  end
  return a, d
end
