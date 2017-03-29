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

unless node[:sahara][:ha][:enabled]
  Chef::Log.info("HA support for sahara is disabled")
  return
end

network_settings = SaharaHelper.network_settings(node)

include_recipe "crowbar-pacemaker::haproxy"

haproxy_loadbalancer "sahara-api" do
  address network_settings[:api][:ha_bind_host]
  port network_settings[:api][:ha_bind_port]
  use_ssl node[:sahara][:api][:protocol] == "https"
  servers CrowbarPacemakerHelper.haproxy_servers_for_service(node, "sahara",
                                                             "sahara-server", "api_port")
  action :nothing
end.run_action(:create)

# Wait for all nodes to reach this point so we know that all nodes will have
# all the required packages installed before we create the pacemaker
# resources
crowbar_pacemaker_sync_mark "sync-sahara before_ha"

# Avoid races when creating pacemaker resources
crowbar_pacemaker_sync_mark "wait-sahara_ha_resources"

rabbit_settings = fetch_rabbitmq_settings
transaction_objects = []

["api", "engine"].each do |service|
  primitive = "sahara-#{service}"

  objects = openstack_pacemaker_controller_clone_for_transaction primitive do
    agent node[:sahara][:ha][service.to_sym][:ra]
    op node[:sahara][:ha][:op]
    order_only_existing "( postgresql #{rabbit_settings[:pacemaker_resource]} cl-keystone )"
  end
  transaction_objects.push(objects)
end

pacemaker_transaction "sahara server" do
  cib_objects transaction_objects.flatten
  # note that this will also automatically start the resources
  action :commit_new
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

crowbar_pacemaker_sync_mark "create-sahara_ha_resources"
