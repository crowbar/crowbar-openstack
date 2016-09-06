module MagnumHelper
  class << self
    def network_settings(node)
      @ip ||= Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "admin").address
      @cluster_admin_ip ||= nil

      if node[:magnum][:ha][:enabled] && !@cluster_admin_ip
        @cluster_admin_ip = CrowbarPacemakerHelper.cluster_vip(node, "admin")
      end

      if node[:magnum][:ha][:enabled]
        bind_host = @ip
        bind_port = node[:magnum][:ha][:ports][:api].to_i
      else
        bind_host = node[:magnum][:api][:bind_open_address] ? "0.0.0.0" : @ip
        bind_port = node[:magnum][:api][:bind_port].to_i
      end

      @network_settings ||= {
        ip: @ip,

        api: {
          bind_host: bind_host,
          bind_port: bind_port,
          ha_bind_host: node[:magnum][:api][:bind_open_address] ? "0.0.0.0" : @cluster_admin_ip,
          ha_bind_port: node[:magnum][:api][:bind_port].to_i
        },
      }
    end
  end
end
