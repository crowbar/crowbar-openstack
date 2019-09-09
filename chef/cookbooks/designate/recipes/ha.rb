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

service_transaction_objects = []

haproxy_loadbalancer "designate-api" do
  address network_settings[:api][:ha_bind_host]
  port network_settings[:api][:ha_bind_port]
  use_ssl node[:designate][:api][:protocol] == "https"
  servers CrowbarPacemakerHelper.haproxy_servers_for_service(node, "designate",
                                                             "designate-server", "api_port")
  action :nothing
end.run_action(:create)

crowbar_pacemaker_sync_mark "wait-designate_producer"

package "openstack-designate-producer"

op = { "monitor" => { "interval" => "10s" }}

producer_primitive = "designate-producer"
pacemaker_primitive producer_primitive do
  agent "systemd:openstack-designate-producer"
  op op
  action :update
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end
service_transaction_objects << "pacemaker_primitive[#{producer_primitive}]"

designate_producer_loc = openstack_pacemaker_controller_only_location_for producer_primitive
service_transaction_objects << "pacemaker_location[#{designate_producer_loc}]"

pacemaker_transaction "designate producer service" do
  cib_objects service_transaction_objects
  # note that this will also automatically start the resources
  action :commit_new
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

crowbar_pacemaker_sync_mark "create-designate_producer"
