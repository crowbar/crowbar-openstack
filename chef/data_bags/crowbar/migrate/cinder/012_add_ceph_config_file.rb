def upgrade ta, td, a, d
  a["volume_defaults"]["rbd"]["use_crowbar"] = ta["volume_defaults"]["rbd"]["use_crowbar"]
  a["volume_defaults"]["rbd"]["config_file"] = ta["volume_defaults"]["rbd"]["config_file"]
  a["volumes"].each do |volume|
    next if volume["backend_driver"] != "rbd"
    volume["rbd"]["use_crowbar"] = ta["volume_defaults"]["rbd"]["use_crowbar"]
    volume["rbd"]["config_file"] = ta["volume_defaults"]["rbd"]["config_file"]
  end

  return a, d
end

def downgrade ta, td, a, d
  a["volume_defaults"]["rbd"].delete "use_crowbar"
  a["volume_defaults"]["rbd"].delete "config_file"
  a["volumes"].each do |volume|
    next if volume["backend_driver"] != "rbd"
    volume["rbd"].delete "use_crowbar"
    volume["rbd"].delete "config_file"
  end

  return a, d
end
