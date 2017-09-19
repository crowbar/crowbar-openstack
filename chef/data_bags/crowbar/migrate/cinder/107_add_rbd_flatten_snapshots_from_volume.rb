def upgrade(ta, td, a, d)
  a["volume_defaults"]["rbd"]["flatten_volume_from_snapshot"] = \
    ta["volume_defaults"]["rbd"]["flatten_volume_from_snapshot"]

  a["volumes"].each do |volume|
    next if volume["backend_driver"] != "rbd"
    volume["rbd"]["flatten_volume_from_snapshot"] = \
      ta["volume_defaults"]["rbd"]["flatten_volume_from_snapshot"]
  end
  return a, d
end

def downgrade(ta, td, a, d)
  a["volume_defaults"]["rbd"].delete "flatten_volume_from_snapshot"

  a["volumes"].each do |volume|
    next if volume["backend_driver"] != "rbd"
    volume["rbd"].delete("flatten_volume_from_snapshot")
  end
  return a, d
end
