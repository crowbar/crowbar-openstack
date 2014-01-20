def upgrade ta, td, a, d
  a["volume"]["netapp"]["nfs_shares"] = ta["volume"]["netapp"]["nfs_shares"]
  return a, d
end


def downgrade ta, td, a, d
  a["volume"]["netapp"].delete("nfs_shares")
  return a, d
end
