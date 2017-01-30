def upgrade(ta, td, a, d)
  unless a["f5"].key?("ha_type")
    a["f5"]["ha_type"] = ta["f5"]["ha_type"]
  end

  return a, d
end

def downgrade(ta, td, a, d)
  unless ta["f5"].key?("ha_type")
    a["f5"].delete("ha_type")
  end

  return a, d
end
