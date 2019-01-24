def upgrade(ta, td, a, d)
  unless a["mysql"].key? "slow_query_logging"
    a["mysql"]["slow_query_logging"] = ta["mysql"]["slow_query_logging"]
  end
  return a, d
end

def downgrade(ta, td, a, d)
  a["mysql"].delete("slow_query_logging") unless ta["mysql"].key? "slow_query_logging"
  return a, d
end
