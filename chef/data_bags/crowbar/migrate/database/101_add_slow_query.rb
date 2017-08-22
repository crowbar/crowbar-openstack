def upgrade(ta, td, a, d)
  a["mysql"]["slow_query"] = ta["mysql"]["slow_query"]
  return a, d
end

def downgrade(ta, td, a, d)
  a["mysql"].delete("slow_query")
  return a, d
end
