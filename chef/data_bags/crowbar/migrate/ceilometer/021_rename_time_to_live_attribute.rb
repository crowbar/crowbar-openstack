def upgrade(ta, td, a, d)
  if a["database"]["time_to_live"]
    a["database"]["metering_time_to_live"] = a["database"]["time_to_live"]
    a["database"].delete("time_to_live")
  end
  return a, d
end

def downgrade(ta, td, a, d)
  if a["database"]["metering_time_to_live"]
    a["database"]["time_to_live"] = a["database"]["metering_time_to_live"]
    a["database"].delete("metering_time_to_live")
  end
  return a, d
end
