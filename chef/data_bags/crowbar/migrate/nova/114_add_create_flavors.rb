def upgrade(ta, td, a, d)
  unless a.key? "create_default_flavors"
    a["create_default_flavors"] = ta["create_default_flavors"]
  end
  return a, d
end

def downgrade(ta, td, a, d)
  unless ta.key? "create_default_flavors"
    a.delete("create_default_flavors")
  end
  return a, d
end
