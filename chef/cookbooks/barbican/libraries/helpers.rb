module BarbicanHelper
  class << self
    def network_settings(node)
      @ip ||= Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "admin").address
      @cluster_admin_ip ||= nil

      if node[:barbican][:ha][:enabled] && !@cluster_admin_ip
        @cluster_admin_ip = CrowbarPacemakerHelper.cluster_vip(node, "admin")
      end

      bind_port = if node[:barbican][:ha][:enabled]
        node[:barbican][:ha][:ports][:api].to_i
      else
        node[:barbican][:api][:bind_port].to_i
      end

      @network_settings ||= {
        ip: @ip,

        api: {
          bind_port: bind_port,
          ha_bind_host: @cluster_admin_ip,
          ha_bind_port: node[:barbican][:api][:bind_port].to_i
        },
      }
    end
  end
end
