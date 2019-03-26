module MemcachedHelper
  def self.get_memcached_servers(memcached_nodes)
    memcached_servers = memcached_nodes.map do |n|
      node_admin_ip = Chef::Recipe::Barclamp::Inventory.get_network_by_type(n,
                                                                            "admin").address
      port = if n.key?(:memcached) && n[:memcached].key?(:port)
        n[:memcached][:port]
      else
        memcached_nodes.first[:memcached][:port]
      end
      "#{node_admin_ip}:#{port}"
    end
    memcached_servers.sort!
    memcached_servers
  end
end
