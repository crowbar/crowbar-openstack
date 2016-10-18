def upgrade(ta, td, a, d)
  a["share_defaults"]["cephfs"] = ta["share_defaults"]["cephfs"]
  return a, d
end

def downgrade(ta, td, a, d)
  if ta["share_defaults"].key? "cephfs"
    a["share_defaults"]["cephfs"] = ta["share_defaults"]["cephfs"]
  else
    a["share_defaults"].delete("cephfs")
  end
  return a, d
end
