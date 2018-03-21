def upgrade(ta, td, a, d)
  unless a.key? "configdrive_use_object_store"
    a["configdrive_use_object_store"] = ta["configdrive_use_object_store"]
  end

  return a, d
end

def downgrade(ta, td, a, d)
  a.delete("configdrive_use_object_store")
  return a, d
end
