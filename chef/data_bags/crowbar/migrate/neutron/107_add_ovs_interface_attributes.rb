def upgrade(ta, td, a, d)
  unless a["ovs"].key? "of_interface"
    a["ovs"]["of_interface"] = ta["ovs"]["of_interface"]
  end

  unless a["ovs"].key? "ovsdb_interface"
    a["ovs"]["ovsdb_interface"] = ta["ovs"]["ovsdb_interface"]
  end

  return a, d
end

def downgrade(ta, td, a, d)
  if ta.key?("ovs") && a.key?("ovs")
    unless ta["ovs"].key?("of_interface")
      a["ovs"].delete("of_interface")
    end
    unless ta["ovs"].key?("ovsdb_interface")
      a["ovs"].delete("ovsdb_interface")
    end
  end

  return a, d
end
