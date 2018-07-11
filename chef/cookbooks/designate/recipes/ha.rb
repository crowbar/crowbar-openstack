# Copyright 2016, SUSE Linux GmbH
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

unless node[:designate][:ha][:enabled]
  Chef::Log.info("HA support for designate is disabled")
  return
end

network_settings = DesignateHelper.network_settings(node)

include_recipe "crowbar-pacemaker::haproxy"

haproxy_loadbalancer "designate-api" do
  address network_settings[:api][:ha_bind_host]
  port network_settings[:api][:ha_bind_port]
  use_ssl node[:designate][:api][:protocol] == "https"
  servers CrowbarPacemakerHelper.haproxy_servers_for_service(node, "designate",
                                                             "designate-server", "api_port")
  action :nothing
end.run_action(:create)
