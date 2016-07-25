def upgrade(ta, td, a, d)
  a["ovs"] ||= {}
  a["ovs"]["tunnel_csum"] = ta["ovs"]["tunnel_csum"]

  return a, d
end

def downgrade(ta, td, a, d)
  if a.key?("ovs")
    a["ovs"].delete("tunnel_csum")
  end

  return a, d
end
