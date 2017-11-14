def upgrade(ta, td, a, d)
  a["client"] ||= {}
  unless a["client"]["heartbeat_timeout"]
    a["client"]["heartbeat_timeout"] = ta["client"]["heartbeat_timeout"]
  end
  return a, d
end

def downgrade(ta, td, a, d)
  if ta.key?("client")
    a["client"].delete("heartbeat_timeout") unless ta["client"].key?("heartbeat_timeout")
  else
    a.delete("client")
  end
  return a, d
end
