def upgrade(ta, td, a, d)
  a["mysql"]["slow_query_logging"] = ta["mysql"]["slow_query_logging"]
  return a, d
end

def downgrade(ta, td, a, d)
  a["mysql"].delete("slow_query_logging")
  return a, d
end
