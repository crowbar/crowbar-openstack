def upgrade ta, td, a, d
  a["volume"]["local"] = {}
  a["volume"]["local"]["volume_name"] = a["volume"]["volume_name"]
  a["volume"]["local"]["file_name"] = a["volume"]["local_name"]
  a["volume"]["local"]["file_size"] = a["volume"]["local_size"]

  a["volume"]["raw"] = {}
  a["volume"]["raw"]["volume_name"] = a["volume"]["volume_name"]
  a["volume"]["raw"]["cinder_raw_method"] = a["volume"]["cinder_raw_method"]

  a["volume"].delete("volume_name")
  a["volume"].delete("cinder_raw_method")
  a["volume"].delete("local_name")
  a["volume"].delete("local_size")
  return a, d
end

def downgrade ta, td, a, d
  a["volume"]["volume_name"] = a["volume"]["local"]["volume_name"]
  a["volume"]["cinder_raw_method"] = a["volume"]["raw"]["cinder_raw_method"]
  a["volume"]["local_name"] = a["volume"]["local"]["file_name"]
  a["volume"]["local_size"] = a["volume"]["local"]["file_size"]

  a["volume"]["local"].delete("volume_name")
  a["volume"]["local"].delete("file_name")
  a["volume"]["local"].delete("file_size")
  a["volume"].delete("local")

  a["volume"]["raw"].delete("volume_name")
  a["volume"]["raw"].delete("cinder_raw_method")
  a["volume"].delete("raw")
  return a, d
end
