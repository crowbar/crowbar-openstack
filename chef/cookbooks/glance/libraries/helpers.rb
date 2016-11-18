module GlanceHelper
  class << self
    def network_settings(node)
      @ip ||= Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "admin").address
      @cluster_admin_ip ||= nil

      if node[:glance][:ha][:enabled] && !@cluster_admin_ip
        @cluster_admin_ip = CrowbarPacemakerHelper.cluster_vip(node, "admin")
      end

      @network_settings ||= {
        ip: @ip,

        api: {
          bind_host: !node[:glance][:ha][:enabled] && node[:glance][:api][:bind_open_address] ? "0.0.0.0" : @ip,
          bind_port: node[:glance][:ha][:enabled] ? node[:glance][:ha][:ports][:api].to_i : node[:glance][:api][:bind_port].to_i,
          ha_bind_host: node[:glance][:api][:bind_open_address] ? "0.0.0.0" : @cluster_admin_ip,
          ha_bind_port: node[:glance][:api][:bind_port].to_i
        },

        registry: {
          bind_host: @ip,
          bind_port: node[:glance][:ha][:enabled] ? node[:glance][:ha][:ports][:registry].to_i : node[:glance][:registry][:bind_port].to_i,
          ha_bind_host: @cluster_admin_ip,
          ha_bind_port: node[:glance][:registry][:bind_port].to_i
        }
      }
    end
  end

  def self.check_user(node, expected_username, expected_uid)
    node["etc"]["passwd"].each do |username, attrs|
      if username == expected_username
        if attrs["uid"] != expected_uid
          message = "#{username} user exists on the system, "\
                    "but it's uid is different from #{expected_uid}"
          Chef::Log.fatal(message)
          raise message
        else
          break
        end
      end

      if attrs["uid"] == expected_uid
        message = "#{expected_uid} already in use by user #{username}"
        Chef::Log.fatal(message)
        raise message
      end
    end
  end

  def self.check_group(node, expected_groupname, expected_gid)
    node["etc"]["group"].each do |groupname, attrs|
      if groupname == expected_groupname
        if attrs["gid"] != expected_gid
          message = "#{groupname} group exists on the system, "\
                    "but it's gid is different from #{expected_gid}"
          Chef::Log.fatal(message)
          raise message
        else
          break
        end
      end

      if attrs["gid"] == expected_gid
        message = "#{expected_gid} already in use by user #{groupname}"
        Chef::Log.fatal(message)
        raise message
      end
    end
  end

  def self.verify_user_and_group_ids(node)
    Chef::Log.info("verifying user and group ids")
    check_user(node, node[:glance][:user], node[:glance][:uid])
    check_group(node, node[:glance][:group], node[:glance][:gid])
  end

end
