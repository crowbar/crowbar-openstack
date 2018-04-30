def upgrade(ta, td, a, d)
  if a["alarm_history_ttl"].nil? || a["alarm_history_ttl"].empty?
    service = ServiceObject.new "fake-logger"
    a["alarm_history_ttl"] = ta["alarm_history_ttl"]
  end
  return a, d
end

def downgrade(ta, td, a, d)
  a.delete("alarm_history_ttl")
  return a, d
end
