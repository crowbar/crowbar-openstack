def upgrade(ta, td, a, d)
  unless a["share_defaults"].key? "netapp-managed"
    a["share_defaults"]["netapp-managed"] = ta["share_defaults"]["netapp-managed"]
  end
  return a, d
end

def downgrade(ta, td, a, d)
  unless ta["share_defaults"].key? "netapp-managed"
    a["share_defaults"].delete("netapp-managed")
  end
  return a, d
end
