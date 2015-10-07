def upgrade(ta, td, a, d)
  a["vcenter"]["port"] = ta["vcenter"]["port"]
  return a, d
end

def downgrade(ta, td, a, d)
  a["vcenter"].delete("port")
  return a, d
end
