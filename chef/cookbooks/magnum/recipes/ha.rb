# Copyright 2016 SUSE Linux GmbH
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

unless node[:magnum][:ha][:enabled]
  log "HA support for magnum is not enabled"
  return
end

log "Setting up magnum HA support"

network_settings = MagnumHelper.network_settings(node)

ssl_enabled = (node[:magnum][:api][:protocol] == "https")

include_recipe "crowbar-pacemaker::haproxy"

haproxy_loadbalancer "magnum-api" do
  address network_settings[:api][:ha_bind_host]
  port network_settings[:api][:ha_bind_port]
  use_ssl ssl_enabled
  servers CrowbarPacemakerHelper.haproxy_servers_for_service(node, "magnum", "magnum-server", "api")
  action :nothing
end.run_action(:create)
