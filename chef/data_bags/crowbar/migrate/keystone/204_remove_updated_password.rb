def upgrade(ta, td, a, d)
  a["admin"].delete("updated_password")
  nodes = NodeObject.find("roles:keystone-server")
  nodes.each do |node|
    node[:keystone][:admin][:old_password] = node[:keystone][:admin][:password]
    node.save
  end
  return a, d
end

def downgrade(ta, td, a, d)
  a["admin"]["updated_password"] = ta["admin"]["updated_password"]
  return a, d
end
