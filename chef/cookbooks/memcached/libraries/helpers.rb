module MemcachedHelper
  def self.get_memcached_servers(node, memcached_nodes = [])
    memcached_nodes = [node] if memcached_nodes.empty?
    memcached_servers = memcached_nodes.map do |n|
      node_admin_ip = Chef::Recipe::Barclamp::Inventory.get_network_by_type(n,
                                                                            "admin").address
      "#{node_admin_ip}:#{node[:memcached][:port]}"
    end
    memcached_servers.sort!
    memcached_servers
  end
end
