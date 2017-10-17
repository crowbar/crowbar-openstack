def upgrade(ta, td, a, d)
  a["mysql"]["expire_logs_days"] = ta["mysql"]["expire_logs_days"]
  return a, d
end

def downgrade(ta, td, a, d)
  a["mysql"].delete("expire_logs_days")
  return a, d
end
