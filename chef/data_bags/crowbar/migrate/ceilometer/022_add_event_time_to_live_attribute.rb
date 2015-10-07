def upgrade(ta, td, a, d)
  a["database"]["event_time_to_live"] = ta["database"]["event_time_to_live"]
  return a, d
end

def downgrade(ta, td, a, d)
  a["database"].delete("event_time_to_live")
  return a, d
end
