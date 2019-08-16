module MemcachedHelper
  def self.get_memcached_servers(memcached_nodes)
    Chef::Log.info("Getting memcached servers for #{memcached_nodes.inspect}")
    memcached_servers = memcached_nodes.map do |n|
      Chef::Log.info("Processing #{n.inspect}")
      node_admin_ip = Chef::Recipe::Barclamp::Inventory.get_network_by_type(n,
                                                                            "admin").address
      Chef::Log.info("IP #{node_admin_ip}")
      port = if n.key?(:memcached) && n[:memcached].key?(:port)
        n[:memcached][:port]
      else
        memcached_nodes.first[:memcached][:port]
      end
      "#{node_admin_ip}:#{port}"
    end
    Chef::Log.info("Memcached servers #{memcached_servers.inspect}")
    memcached_servers.sort!
    memcached_servers
  end
end
