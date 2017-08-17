# Copyright 2017 SUSE
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

module IronicHelper
  class << self
    def auth_url(keystone_settings)
      "#{keystone_settings["protocol"]}://"\
      "#{keystone_settings["internal_url_host"]}:"\
      "#{keystone_settings["service_port"]}/v3"
    end

    def openstack_command(keystone_settings)
      insecure = keystone_settings["insecure"] ? "--insecure" : ""
      "openstack --os-username #{keystone_settings["admin_user"]}"\
      " --os-auth-type password --os-identity-api-version 3"\
      " --os-password #{keystone_settings["admin_password"]}"\
      " --os-tenant-name #{keystone_settings["admin_tenant"]}"\
      " --os-auth-url #{auth_url(keystone_settings)} #{insecure}"
    end

    def swift_settings(node, glance)
      swift = CrowbarUtilsSearch.node_search_with_cache(node, "roles:swift-proxy").first || {}
      # configure swift only if some agent_* drivers are enabled
      return unless swift && node[:ironic][:enabled_drivers].any? { |d| d.start_with?("agent_") }

      glance_keystone_settings = KeystoneHelper.keystone_settings(glance, "glance")

      swift_command = "swift --os-username #{glance_keystone_settings["service_user"]}"
      swift_command << " --os-password #{glance_keystone_settings["service_password"]}"
      swift_command << " --os-tenant-name #{glance_keystone_settings["service_tenant"]}"
      swift_command << " --os-identity-api-version 3"
      swift_command << " --os-auth-url #{auth_url(glance_keystone_settings)}"
      swift_command << (swift[:swift][:ssl][:insecure] ? " --insecure" : "")

      get_glance_account = "#{swift_command} stat | grep -m1 Account: | awk '{print $2}'"
      glance_account = Mixlib::ShellOut.new(get_glance_account).run_command.stdout.chomp

      get_tempurl_key = "#{swift_command} stat | grep -m1 'Meta Temp-Url-Key:' | awk '{print $3}'"
      tempurl_key = Mixlib::ShellOut.new(get_tempurl_key).run_command.stdout.chomp

      # use IP as this will be used by agent which can have no DNS configured
      if swift[:swift][:ha][:enabled]
        cluster_vhostname = CrowbarPacemakerHelper.cluster_vhostname(swift)
        swift_address = CrowbarPacemakerHelper.cluster_vip(swift, "admin", cluster_vhostname)
      else
        swift_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(swift, "admin").address
      end

      {
        tempurl_key: tempurl_key,
        glance_container: glance[:glance][:swift][:store_container],
        glance_account: glance_account,
        protocol: swift[:swift][:ssl][:enabled] ? "https" : "http",
        host: swift_address,
        port: swift[:swift][:ports][:proxy]
      }
    end

    def ironic_net_id(keystone_settings)
      cmd = "#{openstack_command(keystone_settings)} network show ironic -f value -c id"
      Mixlib::ShellOut.new(cmd).run_command.stdout.chomp
    end
  end
end
