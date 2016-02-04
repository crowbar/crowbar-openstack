def upgrade(ta, td, a, d)
  unless a.key? "default_volume_type"
    a["default_volume_type"] = ta["default_volume_type"]
  end
  return a, d
end

def downgrade(ta, td, a, d)
  unless ta.key? "default_volume_type"
    a.delete("default_volume_type")
  end
  return a, d
end
