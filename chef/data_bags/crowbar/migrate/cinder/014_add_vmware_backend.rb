def upgrade ta, td, a, d
  a["volume_defaults"]["vmware"] = ta["volume_defaults"]["vmware"]
  return a, d
end

def downgrade ta, td, a, d
  a["volume_defaults"].delete("vmware")
  return a, d
end
