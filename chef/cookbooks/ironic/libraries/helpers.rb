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
      env = "OS_USERNAME='#{keystone_settings["admin_user"]}' "
      env << "OS_PASSWORD='#{keystone_settings["admin_password"]}' "
      env << "OS_PROJECT_NAME='#{keystone_settings["admin_tenant"]}' "
      env << "OS_AUTH_URL='#{auth_url(keystone_settings)}'"
      "#{env} openstack #{insecure}"
    end

    def swift_settings(node, glance)
      swift = CrowbarUtilsSearch.node_search_with_cache(node, "roles:swift-proxy").first || {}
      # configure swift only if some agent_* drivers are enabled
      return unless swift && node[:ironic][:enabled_drivers].any? { |d| d.start_with?("agent_") }

      glance_keystone_settings = KeystoneHelper.keystone_settings(glance, "glance")

      env = {
        "OS_USERNAME" => glance_keystone_settings["service_user"],
        "OS_PASSWORD" => glance_keystone_settings["service_password"],
        "OS_PROJECT_NAME" => glance_keystone_settings["service_tenant"],
        "OS_AUTH_URL" => auth_url(glance_keystone_settings),
        "OS_IDENTITY_API_VERSION" => "3"
      }
      insecure = swift[:swift][:ssl][:insecure] ? " --insecure" : ""
      swift_command = "swift #{insecure}"

      get_glance_account = "#{swift_command} stat | grep -m1 Account: | awk '{print $2}'"
      glance_account = Mixlib::ShellOut.new(get_glance_account,
                                            environment: env).run_command.stdout.chomp

      get_tempurl_key = "#{swift_command} stat | grep -m1 'Meta Temp-Url-Key:' | awk '{print $3}'"
      tempurl_key = Mixlib::ShellOut.new(get_tempurl_key, environment: env).run_command.stdout.chomp

      {
        tempurl_key: tempurl_key,
        glance_container: glance[:glance][:swift][:store_container],
        glance_account: glance_account,
        protocol: swift[:swift][:ssl][:enabled] ? "https" : "http",
        service_user: swift[:swift][:service_user],
        service_password: swift[:swift][:service_password],
        host: CrowbarHelper.get_host_for_admin_url(swift, swift[:swift][:ha][:enabled]),
        port: swift[:swift][:ports][:proxy]
      }
    end
  end
end
