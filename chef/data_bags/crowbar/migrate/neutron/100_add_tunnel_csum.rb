def upgrade(ta, td, a, d)
  unless a.key?("ovs") && a["ovs"].key?("tunnel_csum")
    a["ovs"] ||= {}
    a["ovs"]["tunnel_csum"] = ta["ovs"]["tunnel_csum"]
  end

  return a, d
end

def downgrade(ta, td, a, d)
  unless ta.key?("ovs") && ta["ovs"].key?("tunnel_csum")
    if a.key?("ovs")
      a["ovs"].delete("tunnel_csum")
    end
  end

  return a, d
end
