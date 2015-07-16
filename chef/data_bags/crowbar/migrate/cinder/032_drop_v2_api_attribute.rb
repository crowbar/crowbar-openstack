def upgrade ta, td, a, d
  a.delete "enable_v2_api"
  return a, d
end

def downgrade ta, td, a, d
  a["enable_v2_api"] = ta["enable_v2_api"]
  return a, d
end
