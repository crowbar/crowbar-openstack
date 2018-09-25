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

haproxy_loadbalancer "heat-api" do
  address "0.0.0.0"
  port node[:heat][:api][:port]
  use_ssl (node[:heat][:api][:protocol] == "https")
  servers CrowbarPacemakerHelper.haproxy_servers_for_service(node, "heat", "heat-server", "api_port")
  action :nothing
end.run_action(:create)

haproxy_loadbalancer "heat-api-cfn" do
  address "0.0.0.0"
  port node[:heat][:api][:cfn_port]
  use_ssl (node[:heat][:api][:protocol] == "https")
  servers CrowbarPacemakerHelper.haproxy_servers_for_service(node, "heat", "heat-server", "cfn_port")
  action :nothing
end.run_action(:create)

if node[:pacemaker][:clone_stateless_services]
  # Wait for all nodes to reach this point so we know that all nodes will have
  # all the required packages installed before we create the pacemaker
  # resources
  crowbar_pacemaker_sync_mark "sync-heat_before_ha"

  # Avoid races when creating pacemaker resources
  crowbar_pacemaker_sync_mark "wait-heat_ha_resources"

  rabbit_settings = fetch_rabbitmq_settings
  services = ["engine", "api", "api_cfn"]
  transaction_objects = []

  services.each do |service|
    primitive_name = "heat-#{service}".tr("_","-")
    ordering = "( postgresql #{rabbit_settings[:pacemaker_resource]} cl-keystone cl-nova-api )"

    objects = openstack_pacemaker_controller_clone_for_transaction primitive_name do
      agent node[:heat][:ha][service.to_sym][:agent]
      op node[:heat][:ha][service.to_sym][:op]
      order_only_existing ordering
    end
    transaction_objects.push(objects)
  end

  pacemaker_transaction "heat server" do
    cib_objects transaction_objects.flatten
    # note that this will also automatically start the resources
    action :commit_new
    only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end

  crowbar_pacemaker_sync_mark "create-heat_ha_resources"
end
