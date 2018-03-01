def upgrade(ta, td, a, d)
  attr = "allow_automatic_lbaas_agent_failover"
  a[attr] = ta[attr] unless a.key? attr
  return a, d
end

def downgrade(ta, td, a, d)
  attr = "allow_automatic_lbaas_agent_failover"
  a.delete(attr) unless ta.key? attr
  return a, d
end
