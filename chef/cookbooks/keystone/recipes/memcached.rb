package "memcached"

case node[:platform_family]
when "rhel"
  package "python-memcached"
when "suse"
  package "python-python-memcached"
end

node.set[:memcached][:listen] =
  Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "admin").address

memcached_instance "keystone"
