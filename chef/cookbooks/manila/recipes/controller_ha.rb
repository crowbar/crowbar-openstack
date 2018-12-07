# Copyright 2015 SUSE
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

unless node[:manila][:ha][:enabled]
  log "HA support for manila is disabled"
  return
end

log "HA support for manila is enabled"

cluster_admin_ip = CrowbarPacemakerHelper.cluster_vip(node, "admin")

include_recipe "crowbar-pacemaker::haproxy"

haproxy_loadbalancer "manila-api" do
  address node[:manila][:api][:bind_open_address] ?
    "0.0.0.0" : cluster_admin_ip
  port node[:manila][:api][:bind_port]
  use_ssl (node[:manila][:api][:protocol] == "https")
  servers CrowbarPacemakerHelper.haproxy_servers_for_service(node,
                                                             "manila",
                                                             "manila-server",
                                                             "api")
  action :nothing
end.run_action(:create)
