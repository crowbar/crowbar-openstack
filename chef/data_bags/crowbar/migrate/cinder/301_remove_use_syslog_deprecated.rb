def upgrade(tattr, tdep, attr, dep)
  a.delete("use_syslog")
  return a, d
end

def downgrade(tattr, tdep, attr, deps)
  a["use_syslog"] = ta["use_syslog"]
  return a, d
end
