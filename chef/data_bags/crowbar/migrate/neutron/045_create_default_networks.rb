def upgrade(ta, td, a, d)
  unless a.key? "create_default_networks"
    a["create_default_networks"] = ta["create_default_networks"]
  end
  return a, d
end

def downgrade(ta, td, a, d)
  a.delete("create_default_networks")
  return a, d
end
