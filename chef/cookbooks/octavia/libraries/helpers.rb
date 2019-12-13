# Copyright 2019, SUSE LLC.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

module OctaviaHelper
  class << self
    def get_neutron_endpoint(node)
      neutron = CrowbarUtilsSearch.node_search_with_cache(node, "roles:neutron-server").first || {}
      neutron_protocol = neutron[:neutron][:api][:protocol]
      neutron_ha = neutron[:neutron][:ha][:server][:enabled]
      neutron_server_host = CrowbarHelper.get_host_for_admin_url(neutron, neutron_ha)
      neutron_server_port = neutron[:neutron][:api][:service_port]
      neutron_protocol + "://" + neutron_server_host + ":" + neutron_server_port.to_s
    end

    def get_nova_endpoint(node)
      nova = CrowbarUtilsSearch.node_search_with_cache(node, "roles:nova-controller").first || {}
      nova_protocol = nova[:nova][:ssl][:enabled] ? "https" : "http"
      nova_server_host = CrowbarHelper.get_host_for_admin_url(nova, nova[:nova][:ha][:enabled])
      nova_server_port = nova[:nova][:ports][:api]
      nova_protocol + "://" + nova_server_host + ":" + nova_server_port.to_s + "/v2.1"
    end

    def get_barbican_endpoint(node)
      barbican = CrowbarUtilsSearch.node_search_with_cache(node, "roles:barbican-controller").first
      if !barbican.nil?
        barbican_protocol = barbican[:barbican][:api][:protocol]
        barbican_server_host = CrowbarHelper.get_host_for_admin_url(barbican, barbican[:barbican][:ha][:enabled])
        barbican_server_port = barbican[:barbican][:api][:bind_port]
        barbican_protocol + "://" + barbican_server_host + ":" + barbican_server_port.to_s
      else
        ""
      end
    end

    def get_openstack_command(node, config)
      key_settings = KeystoneHelper.keystone_settings(node, "octavia")

      env = "OS_USERNAME='#{key_settings["service_user"]}' "
      env << "OS_PASSWORD='#{key_settings["service_password"]}' "
      env << "OS_PROJECT_NAME='#{key_settings["service_tenant"]}' "
      env << "OS_AUTH_URL='#{key_settings["internal_auth_url"]}' "
      env << "OS_REGION_NAME='#{key_settings["endpoint_region"]}' "
      env << "OS_INTERFACE=internal "
      env << "OS_USER_DOMAIN_NAME=Default "
      env << "OS_PROJECT_DOMAIN_NAME=Default "
      env << "OS_IDENTITY_API_VERSION=3"

      ssl_insecure = CrowbarOpenStackHelper.insecure(config) || key_settings["insecure"]
      "#{env} openstack#{ssl_insecure ? " --insecure" : ""}"
    end

    def get_healthmanager_nodes(node, net_name)
      list = CrowbarUtilsSearch.node_search_with_cache(node, "roles:octavia-backend") || {}

      hm_port = node[:octavia]["health_manager"][:port]
      hm_node_list = []
      list.each do |e|
        address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(e, net_name).address
        str = address + ":" + hm_port.to_s
        hm_node_list << str unless hm_node_list.include?(str)
      end

      hm_node_list.join(",")
    end

    def network_settings(node)
      ha_enabled = node[:octavia][:ha][:enabled]
      @admin_ip ||= Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "admin").address
      @cluster_admin_ip ||= nil

      if ha_enabled && !@cluster_admin_ip
        @cluster_admin_ip = CrowbarPacemakerHelper.cluster_vip(node, "admin")
      end

      @network_settings ||= {
        api: {
          bind_host: if !ha_enabled && node[:octavia][:api][:bind_open_address]
                       "0.0.0.0"
                     else
                       @admin_ip
                     end,
          bind_port: if ha_enabled
                       node[:octavia][:ha][:ports][:api].to_i
                     else
                       node[:octavia][:api][:port].to_i
                     end,
          ha_bind_host: if node[:octavia][:api][:bind_open_address]
                          "0.0.0.0"
                        else
                          @cluster_admin_ip
                        end,
          ha_bind_port: node[:octavia][:api][:port].to_i
        },
        health_manager: {
          bind_host: if node[:octavia][:health_manager][:bind_open_address]
                       "0.0.0.0"
                     else
                       @admin_ip
                     end,
          bind_port: node[:octavia][:health_manager][:port].to_i
        },
      }
    end

    def conf_file(name)
      ["/etc/octavia/octavia.conf.d/100-octavia.conf",
       "/etc/octavia/octavia.conf.d/110-#{name}.conf"]
    end

    def bind_host(node, name)
      network_settings = OctaviaHelper.network_settings(node)

      if name == "api"
        network_settings[:api][:bind_host]
      else
        network_settings[:health_manager][:bind_host]
      end
    end

    def bind_port(node, name)
      network_settings = OctaviaHelper.network_settings(node)

      if name == "api"
        network_settings[:api][:bind_port]
      else
        network_settings[:health_manager][:bind_port]
      end
    end
  end
end
