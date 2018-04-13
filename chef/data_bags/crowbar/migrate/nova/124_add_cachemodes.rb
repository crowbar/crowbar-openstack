def upgrade(ta, td, a, d)
  unless a["kvm"].key? "disk_cachemodes"
    a["kvm"]["disk_cachemodes"] = ta["kvm"]["disk_cachemodes"]
  end
  return a, d
end

def downgrade(ta, td, a, d)
  unless ta["kvm"].key? "disk_cachemodes"
    a["kvm"].delete("disk_cachemodes")
  end
  return a, d
end
