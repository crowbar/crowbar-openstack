def upgrade ta, td, a, d
  a["volume_defaults"]["nfs"] = ta["volume_defaults"]["nfs"]
  return a, d
end

def downgrade ta, td, a, d
  a["volume_defaults"].delete("nfs")
  return a, d
end
