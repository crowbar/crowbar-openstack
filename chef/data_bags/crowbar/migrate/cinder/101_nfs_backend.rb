def upgrade(ta, td, a, d)
  a["volume_defaults"]["nfs"] = ta["volume_defaults"]["nfs"] \
    unless a["volume_defaults"].key?("nfs")
  return a, d
end

def downgrade(ta, td, a, d)
  a["volume_defaults"].delete("nfs") if a["volume_defaults"].key?("nfs")
  return a, d
end
