def upgrade(ta, td, a, d)
  unless a["zvm"].key? "zvm_image_default_password"
    a["zvm"]["zvm_image_default_password"] = ta["zvm"]["zvm_image_default_password"]
    a["zvm"]["zvm_config_drive_inject_password"] = ta["zvm"]["zvm_config_drive_inject_password"]
  end
  return a, d
end

def downgrade(ta, td, a, d)
  unless ta["zvm"].key? "zvm_image_default_password"
    a["zvm"].delete("zvm_image_default_password")
    a["zvm"].delete("zvm_config_drive_inject_password")
  end
  return a, d
end
