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

include_recipe "crowbar-pacemaker::haproxy"

haproxy_loadbalancer "ec2-api" do
  address "0.0.0.0"
  port node[:nova][:ports][:ec2_api]
  use_ssl node[:nova]["ec2-api"][:ssl][:enabled]
  servers CrowbarPacemakerHelper.haproxy_servers_for_service(
    node, "nova", "ec2-api", "ec2_api"
  )
  action :nothing
end.run_action(:create)

haproxy_loadbalancer "ec2-metadata" do
  address "0.0.0.0"
  port node[:nova][:ports][:ec2_metadata]
  use_ssl node[:nova]["ec2-api"][:ssl][:enabled]
  servers CrowbarPacemakerHelper.haproxy_servers_for_service(
    node, "nova", "ec2-api", "ec2_metadata"
  )
  action :nothing
end.run_action(:create)

haproxy_loadbalancer "ec2-s3" do
  address "0.0.0.0"
  port node[:nova][:ports][:ec2_s3]
  use_ssl node[:nova]["ec2-api"][:ssl][:enabled]
  servers CrowbarPacemakerHelper.haproxy_servers_for_service(
    node, "nova", "ec2-api", "ec2_s3"
  )
  action :nothing
end.run_action(:create)

# Wait for all nodes to reach this point so we know that they will have
# all the required packages installed and configuration files updated
# before we create the pacemaker resources.
crowbar_pacemaker_sync_mark "sync-ec2_api_before_ha"

# Avoid races when creating pacemaker resources
crowbar_pacemaker_sync_mark "wait-ec2_api_ha_resources"

services = ["api", "metadata", "s3"]
transaction_objects = []

services.each do |service|
  primitive_ra = if ["rhel", "suse"].include?(node[:platform_family])
    "systemd:openstack-ec2-api-#{service}"
  else
    "systemd:ec2-api-#{service}"
  end

  primitive_name = "ec2-api-#{service}"

  objects = openstack_pacemaker_controller_clone_for_transaction primitive_name do
    agent primitive_ra
    op node[:nova][:ha][:op]
    order_only_existing "( postgresql rabbitmq cl-keystone )"
  end
  transaction_objects.push(objects)
end

pacemaker_transaction "ec2-api" do
  cib_objects transaction_objects.flatten
  # note that this will also automatically start the resources
  action :commit_new
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

crowbar_pacemaker_sync_mark "create-ec2_api_ha_resources"
