#
# Copyright 2019, SUSE LINUX GmbH
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

unless node[:watcher][:ha][:enabled]
  log "HA support for Watcher is not enabled"
  return
end

log "Setting up Watcher HA support"

network_settings = WatcherHelper.network_settings(node)

include_recipe "crowbar-pacemaker::haproxy"

haproxy_loadbalancer "watcher-api" do
  address network_settings[:api][:ha_bind_host]
  port network_settings[:api][:ha_bind_port]
  use_ssl (node[:watcher][:api][:protocol] == "https")
  servers CrowbarPacemakerHelper.haproxy_servers_for_service(node, "watcher", "watcher-server", "api")
  rate_limit node[:watcher][:ha_rate_limit]["watcher-api"]
  action :nothing
end.run_action(:create)
