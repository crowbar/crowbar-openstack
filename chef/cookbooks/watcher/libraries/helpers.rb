module WatcherHelper
  class << self
    def network_settings(node)
      @ip ||= Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "admin").address
      @cluster_admin_ip ||= nil

      if node[:watcher][:ha][:enabled] && !@cluster_admin_ip
        @cluster_admin_ip = CrowbarPacemakerHelper.cluster_vip(node, "admin")
      end

      @network_settings ||= {
        ip: @ip,

        api: {
          bind_host: !node[:watcher][:ha][:enabled] && node[:watcher][:api][:bind_open_address] ? "0.0.0.0" : @ip,
          bind_port: node[:watcher][:ha][:enabled] ? node[:watcher][:ha][:ports][:api].to_i : node[:watcher][:api][:bind_port].to_i,
          ha_bind_host: node[:watcher][:api][:bind_open_address] ? "0.0.0.0" : @cluster_admin_ip,
          ha_bind_port: node[:watcher][:api][:bind_port].to_i
        }

      }
    end
  end
end
