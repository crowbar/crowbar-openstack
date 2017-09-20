def upgrade(ta, td, a, d)
  a["ha_rate_limit"] = ta["ha_rate_limit"] unless a.key? "ha_rate_limit"
  a["ha_rate_limit"]["nova-placement-api"] = ta["ha_rate_limit"]["nova-placement-api"] \
    unless a["ha_rate_limit"].key? "nova-placement-api"
  return a, d
end

def downgrade(ta, td, a, d)
  a["ha_rate_limit"].delete("nova-placement-api") \
    unless ta["ha_rate_limit"].key? "nova-placement-api"
  a.delete("ha_rate_limit") unless ta.key? "ha_rate_limit"
  return a, d
end
