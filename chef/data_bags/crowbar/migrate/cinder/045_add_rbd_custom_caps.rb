def upgrade(ta, td, a, d)
  a["volume_defaults"]["rbd"]["caps"] = ta["volume_defaults"]["rbd"]["caps"]
  a["volumes"].each do |volume|
    next if volume["backend_driver"] != "rbd"
    volume["rbd"]["caps"] = ta["volume_defaults"]["rbd"]["caps"]
  end
  return a, d
end

def downgrade(ta, td, a, d)
  a["volume_defaults"]["rbd"].delete "caps"
  a["volumes"].each do |volume|
    next if volume["backend_driver"] != "rbd"
    volume["rbd"].delete "caps"
  end
  return a, d
end
