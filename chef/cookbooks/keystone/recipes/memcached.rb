package "memcached"

case node[:platform_family]
when "rhel"
  package "python-memcached"
when "suse"
  package "python-python-memcached"
end

node_admin_ip = Barclamp::Inventory.get_network_by_type(node, "admin").address
if node[:memcached][:listen] != node_admin_ip
  node.set[:memcached][:listen] = node_admin_ip
  node.save
end

memcached_instance "keystone"
