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

haproxy_loadbalancer "neutron-server" do
  address node[:neutron][:api][:service_host]
  port node[:neutron][:api][:service_port]
  use_ssl (node[:neutron][:api][:protocol] == "https")
  servers CrowbarPacemakerHelper.haproxy_servers_for_service(node, "neutron", "neutron-server", "server")
  rate_limit node[:neutron][:ha_rate_limit]["neutron-server"]
  action :nothing
end.run_action(:create)

if node[:pacemaker][:clone_stateless_services]
  # Wait for all "neutron-server" nodes to reach this point so we know that they
  # will have all the required packages installed and configuration files updated
  # before we create the pacemaker resources.
  crowbar_pacemaker_sync_mark "sync-neutron_before_ha"

  # Avoid races when creating pacemaker resources
  crowbar_pacemaker_sync_mark "wait-neutron_ha_resources"

  rabbit_settings = fetch_rabbitmq_settings
  transaction_objects = []

  server_primitive_name = "neutron-server"

  objects = openstack_pacemaker_controller_clone_for_transaction server_primitive_name do
    agent node[:neutron][:ha][:server][:server_ra]
    op node[:neutron][:ha][:server][:op]
    order_only_existing "( postgresql #{rabbit_settings[:pacemaker_resource]} cl-keystone )"
  end
  transaction_objects.push(objects)

  if node[:neutron][:use_infoblox]
    infoblox_primitive_name = "infoblox-agent"

    objects = openstack_pacemaker_controller_clone_for_transaction infoblox_primitive_name do
      agent node[:neutron][:ha][:infoblox][:infoblox_ra]
      op node[:neutron][:ha][:infoblox][:op]
      order_only_existing "( postgresql #{rabbit_settings[:pacemaker_resource]} cl-keystone )"
    end
    transaction_objects.push(objects)
  end

  pacemaker_transaction "neutron server" do
    cib_objects transaction_objects.flatten
    # note that this will also automatically start the resources
    action :commit_new
    only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end

  crowbar_pacemaker_sync_mark "create-neutron_ha_resources"
end
