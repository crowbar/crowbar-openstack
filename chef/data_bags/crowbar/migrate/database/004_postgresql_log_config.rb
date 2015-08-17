def upgrade ta, td, a, d
  a["postgresql"]["config"]["log_truncate_on_rotation"] = ta["postgresql"]["config"]["log_truncate_on_rotation"]
  a["postgresql"]["config"]["log_filename"] = ta["postgresql"]["config"]["log_filename"]
  return a, d
end

def downgrade ta, td, a, d
  a["postgresql"]["config"].delete("log_filename")
  a["postgresql"]["config"].delete("log_truncate_on_rotation")
  return a, d
end
