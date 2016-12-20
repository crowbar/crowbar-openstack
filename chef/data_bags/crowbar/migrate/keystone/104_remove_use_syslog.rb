def upgrade(ta, td, a, d)
  a.delete("use_syslog")
  return a, d
end

def downgrade(ta, td, a, d)
  a["use_syslog"] = ta["use_syslog"]
  return a, d
end
