def upgrade(ta, td, a, d)
  a["ovs"].delete("of_interface")
  return a, d
end

def downgrade(ta, td, a, d)
  a["ovs"]["of_interface"] = ta["ovs"]["of_interface"]
  return a, d
end
