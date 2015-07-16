def upgrade ta, td, a, d
  # Careful: upgrading from roxy: the 'volume' attribute will not even exist,
  # since migration 014 will have created 'volume_folder' directly. This only
  # applies to volume_defaults (as roxy didn't have any support for VMWare, so
  # can't have any such backend.
  if a["volume_defaults"]["vmware"]["volume_folder"].nil?
    a["volume_defaults"]["vmware"]["volume_folder"] = a["volume_defaults"]["vmware"]["volume"]
  end
  a["volume_defaults"]["vmware"].delete("volume")

  a["volumes"].each do |volume|
    next if volume["backend_driver"] != "vmware"
    volume["vmware"]["volume_folder"] = volume["vmware"]["volume"]
    volume["vmware"].delete("volume")
  end

  return a, d
end

def downgrade ta, td, a, d
  a["volume_defaults"]["vmware"]["volume"] = a["volume_defaults"]["vmware"]["volume_folder"]
  a["volume_defaults"]["vmware"].delete("volume_folder")

  a["volumes"].each do |volume|
    next if volume["backend_driver"] != "vmware"
    volume["vmware"]["volume"] = volume["vmware"]["volume_folder"]
    volume["vmware"].delete("volume_folder")
  end

  return a, d
end
