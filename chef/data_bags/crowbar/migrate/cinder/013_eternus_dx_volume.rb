def upgrade ta, td, a, d
  a["volume_defaults"]["eternus"] = ta["volume_defaults"]["eternus"]
  return a, d
end

def downgrade ta, td, a, d
  a["volume_defaults"].delete("eternus")
  return a, d
end
