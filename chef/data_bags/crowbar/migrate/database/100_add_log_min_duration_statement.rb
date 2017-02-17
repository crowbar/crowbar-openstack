def upgrade(ta, td, a, d)
  unless a["postgresql"]["config"].key?("log_min_duration_statement")
    a["postgresql"]["config"]["log_min_duration_statement"] = \
      ta["postgresql"]["config"]["log_min_duration_statement"]
  end
  return a, d
end

def downgrade(ta, td, a, d)
  unless ta["postgresql"]["config"].key?("log_min_duration_statement")
    a["postgresql"]["config"].delete("log_min_duration_statement")
  end
  return a, d
end
