def upgrade(ta, td, a, d)
  unless a.key? "image_cache_manager_interval"
    a["image_cache_manager_interval"] = ta["image_cache_manager_interval"]
  end
  return a, d
end

def downgrade(ta, td, a, d)
  unless ta.key? "image_cache_manager_interval"
    a.delete("image_cache_manager_interval")
  end
  return a, d
end
