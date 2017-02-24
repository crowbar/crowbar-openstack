def upgrade(ta, td, a, d)
  unless a.key? "default_schedule_zone"
    a["default_schedule_zone"] = ta["default_schedule_zone"]
  end
  return a, d
end

def downgrade(ta, td, a, d)
  a.delete("default_schedule_zone") unless ta.key?("default_schedule_zone")
  return a, d
end
