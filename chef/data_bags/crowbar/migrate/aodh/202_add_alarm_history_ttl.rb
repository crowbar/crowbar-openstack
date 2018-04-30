def upgrade(ta, td, a, d)
  unless a.key? "alarm_history_ttl"
    a["alarm_history_ttl"] = ta["alarm_history_ttl"]
  end
  return a, d
end

def downgrade(ta, td, a, d)
  unless ta.key? "alarm_history_ttl"
    a.delete("alarm_history_ttl")
  end
  return a, d
end
