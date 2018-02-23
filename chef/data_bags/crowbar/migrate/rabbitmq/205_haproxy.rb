def upgrade(ta, td, a, d)
  a["ha"]["haproxy_enabled"] = ta["ha"]["haproxy_enabled"] unless a["ha"]["haproxy_enabled"]
  return a, d
end

def downgrade(ta, td, a, d)
  a["ha"].delete("haproxy_enabled") unless ta["ha"].key?("haproxy_enabled")
  return a, d
end
