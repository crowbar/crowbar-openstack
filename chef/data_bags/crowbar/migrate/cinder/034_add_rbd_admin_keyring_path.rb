def upgrade ta, td, a, d
  a["volume_defaults"]["rbd"]["admin_keyring"] = ta["volume_defaults"]["rbd"]["admin_keyring"]
  a["volumes"].each do |volume|
    next if volume["backend_driver"] != "rbd"
    volume["rbd"]["admin_keyring"] = ta["volume_defaults"]["rbd"]["admin_keyring"]
  end
  return a, d
end

def downgrade ta, td, a, d
  a["volume_defaults"]["rbd"].delete "admin_keyring"
  a["volumes"].each do |volume|
    next if volume["backend_driver"] != "rbd"
    volume["rbd"].delete "admin_keyring"
  end
  return a, d
end
