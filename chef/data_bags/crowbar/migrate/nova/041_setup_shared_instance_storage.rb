def upgrade(ta, td, a, d)
  a["setup_shared_instance_storage"] = a["use_shared_instance_storage"]
  a["use_shared_instance_storage"] = ta["use_shared_instance_storage"]
  return a, d
end

def downgrade(ta, td, a, d)
  a["use_shared_instance_storage"] = a["setup_shared_instance_storage"]
  a.delete("setup_shared_instance_storage")
  return a, d
end
