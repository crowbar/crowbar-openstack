def upgrade(ta, td, a, d)
  a["public_network_name"] = ta["public_network_name"] unless a.key? "public_network_name"

  return a, d
end

def downgrade(ta, td, a, d)
  a.delete("public_network_name") unless ta.key? "public_network_name"

  return a, d
end
