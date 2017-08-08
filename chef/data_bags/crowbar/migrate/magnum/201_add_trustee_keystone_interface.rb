def upgrade(ta, td, a, d)
  unless a["trustee"].key?("keystone_interface")
    a["trustee"]["keystone_interface"] = ta["trustee"]["keystone_interface"]
  end
  return a, d
end

def downgrade(ta, td, a, d)
  unless ta["trustee"].key?("keystone_interface")
    a["trustee"].delete("keystone_interface")
  end
  return a, d
end
