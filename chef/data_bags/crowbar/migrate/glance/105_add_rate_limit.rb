def upgrade(ta, td, a, d)
  a["ha_rate_limit"] = ta["ha_rate_limit"] unless a.key? "ha_rate_limit"
  return a, d
end

def downgrade(ta, td, a, d)
  a.delete("ha_rate_limit") unless ta.key? "ha_rate_limit"
  return a, d
end
