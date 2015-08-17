def upgrade ta, td, a, d
  a.delete "tempest_path"
  return a, d
end

def downgrade ta, td, a, d
  a["tempest_path"] = "/opt/tempest"
  return a, d
end
