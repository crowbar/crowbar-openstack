def upgrade(ta, td, a, d)
  unless a["mysql"].key? "expire_logs_days"
    a["mysql"]["expire_logs_days"] = ta["mysql"]["expire_logs_days"]
  end
  return a, d
end

def downgrade(ta, td, a, d)
  a["mysql"].delete("expire_logs_days") unless ta["mysql"].key? "expire_logs_days"
  return a, d
end
