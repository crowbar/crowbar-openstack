# Copyright 2016 SUSE, Inc.
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

haproxy_loadbalancer "aodh-api" do
  address "0.0.0.0"
  port node[:aodh][:api][:port]
  use_ssl (node[:aodh][:api][:protocol] == "https")
  servers CrowbarPacemakerHelper.haproxy_servers_for_service(node, "aodh", "aodh-server", "api")
  action :nothing
end.run_action(:create)

# Wait for all nodes to reach this point so we know that they will have
# all the required packages installed and configuration files updated
# before we create the pacemaker resources.
crowbar_pacemaker_sync_mark "sync-aodh_before_ha"

# Avoid races when creating pacemaker resources
crowbar_pacemaker_sync_mark "wait-aodh_ha_resources"

transaction_objects = []

node[:aodh][:platform][:services].each do |service|
  primitive_name = "aodh-#{service}"

  objects = openstack_pacemaker_controller_clone_for_transaction primitive_name do
    agent node[:aodh][:ha][service.to_sym][:agent]
    op node[:aodh][:ha][service.to_sym][:op]
    order_only_existing "( postgresql rabbitmq cl-keystone )"
  end
  transaction_objects.push(objects)
end

pacemaker_transaction "aodh" do
  cib_objects transaction_objects.flatten
  # note that this will also automatically start the resources
  action :commit_new
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

crowbar_pacemaker_sync_mark "create-aodh_ha_resources"

include_recipe "crowbar-pacemaker::apache"
