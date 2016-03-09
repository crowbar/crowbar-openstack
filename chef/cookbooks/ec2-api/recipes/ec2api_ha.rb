# Copyright 2017 SUSE, Inc.
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

unless node[:nova][:ha][:enabled]
  log "HA support for ec2-api is disabled"
  return
end

log "Setting up ec2-api HA support"

include_recipe "crowbar-pacemaker::haproxy"

haproxy_loadbalancer "ec2-api" do
  address "0.0.0.0"
  port node[:nova][:ports][:ec2_api]
  use_ssl false
  servers CrowbarPacemakerHelper.haproxy_servers_for_service(
    node, "nova", "ec2-api", "ec2_api"
  )
  action :nothing
end.run_action(:create)

haproxy_loadbalancer "ec2-metadata" do
  address "0.0.0.0"
  port node[:nova][:ports][:ec2_metadata]
  use_ssl false
  servers CrowbarPacemakerHelper.haproxy_servers_for_service(
    node, "nova", "ec2-api", "ec2_metadata"
  )
  action :nothing
end.run_action(:create)

# Wait for all nodes to reach this point so we know that they will have
# all the required packages installed and configuration files updated
# before we create the pacemaker resources.
crowbar_pacemaker_sync_mark "sync-ec2_api_before_ha"

# Avoid races when creating pacemaker resources
crowbar_pacemaker_sync_mark "wait-ec2_api_ha_resources"

transaction_objects = []
primitives = []

["api", "metadata", "s3"].each do |service|
  primitive_name = "ec2-api-#{service}"
  primitive_ra = if ["rhel", "suse"].include?(node[:platform_family])
    "systemd:openstack-ec2-api-#{service}"
  else
    "systemd:ec2-api-#{service}"
  end

  pacemaker_primitive primitive_name do
    agent primitive_ra
    op node[:nova][:ha][:op]
    action :update
    only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end

  primitives << primitive_name
  transaction_objects << "pacemaker_primitive[#{primitive_name}]"
end

group_name = "g-ec2-api"
pacemaker_group group_name do
  members primitives
  action :update
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end
transaction_objects << "pacemaker_group[#{group_name}]"

clone_name = "cl-#{group_name}"
pacemaker_clone clone_name do
  rsc group_name
  meta CrowbarPacemakerHelper.clone_meta(node)
  action :update
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end
transaction_objects << "pacemaker_clone[#{clone_name}]"

order_only_existing = ["rabbitmq", "cl-keystone", clone_name]

location_name = openstack_pacemaker_controller_only_location_for clone_name
transaction_objects << "pacemaker_location[#{location_name}]"

pacemaker_transaction "ec2-api" do
  cib_objects transaction_objects
  # note that this will also automatically start the resources
  action :commit_new
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

crowbar_pacemaker_order_only_existing "o-#{clone_name}" do
  ordering order_only_existing
  score "Optional"
  action :create
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

crowbar_pacemaker_sync_mark "create-ec2_api_ha_resources"
