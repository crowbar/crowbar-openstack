def upgrade(ta, td, a, d)
  a["log_level"] = ta["log_level"] unless a["log_level"]
  return a, d
end

def downgrade(ta, td, a, d)
  a.delete("log_level") unless ta.key?("log_level")
  return a, d
end
