# Copyright 2014 SUSE
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

include_recipe "crowbar-pacemaker::haproxy"

haproxy_loadbalancer "horizon" do
  address "0.0.0.0"
  port 80
  use_ssl false
  servers CrowbarPacemakerHelper.haproxy_servers_for_service(node, "horizon", "horizon-server", "plain")
  options ["defaults", "httpchk"]
  check ({ inter: 1000, downinter: 3000, rise: 3, fall: 1 })
  action :nothing
end.run_action(:create)

if node[:horizon][:apache][:ssl]
  haproxy_loadbalancer "horizon-ssl" do
    address "0.0.0.0"
    port 443
    use_ssl true
    servers CrowbarPacemakerHelper.haproxy_servers_for_service(node, "horizon", "horizon-server", "ssl")
    check ({ inter: 1000, downinter: 3000, rise: 3, fall: 1 })
    action :nothing
  end.run_action(:create)
end

# Wait for all nodes to reach this point so we know that all nodes will have
# all the required packages installed before we create the pacemaker
# resources
crowbar_pacemaker_sync_mark "sync-horizon_before_ha"

# no wait/create sync mark as it's done in crowbar-pacemaker itself

include_recipe "crowbar-pacemaker::apache"
