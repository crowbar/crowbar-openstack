def upgrade(ta, td, a, d)
  if (a["infoblox"]["cloud_data_center_id"]).zero?
    a["infoblox"]["cloud_data_center_id"] = 1
  end
  return a, d
end

def downgrade(ta, td, a, d)
  a["infoblox"]["cloud_data_center_id"] = ta["infoblox"]["cloud_data_center_id"]
  return a, d
end
