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

admin_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "admin").address

haproxy_loadbalancer "horizon" do
  # Support IPv4 and IPv6
  if NetworkHelper.ipv6(admin_address)
    address "::"
  else
    address "0.0.0.0"
  end
  port 80
  use_ssl false
  servers CrowbarPacemakerHelper.haproxy_servers_for_service(node, "horizon", "horizon-server", "plain")
  action :nothing
end.run_action(:create)

if node[:horizon][:apache][:ssl]
  haproxy_loadbalancer "horizon-ssl" do
    # Support IPv4 and IPv6
    if NetworkHelper.ipv6(admin_address)
      address "::"
    else
      address "0.0.0.0"
    end
    port 443
    use_ssl true
    servers CrowbarPacemakerHelper.haproxy_servers_for_service(node, "horizon", "horizon-server", "ssl")
    action :nothing
  end.run_action(:create)
end

# Once HAProxy is taking care of :80 and :443 we need to remove this
# from Apache realm.  This requires update the node information from
# Apache, and maybe the listen.conf file
if node[:apache][:listen_ports].include?("80") || node[:apache][:listen_ports].include?("443")
  node.set[:apache][:listen_ports] = []
  node.save
  include_recipe "apache2::default"
end
