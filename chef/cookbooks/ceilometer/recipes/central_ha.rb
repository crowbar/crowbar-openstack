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

# Wait for all nodes to reach this point so we know that they will have
# all the required packages installed and configuration files updated
# before we create the pacemaker resources.
crowbar_pacemaker_sync_mark "sync-ceilometer_central_before_ha"

# Avoid races when creating pacemaker resources
crowbar_pacemaker_sync_mark "wait-ceilometer_central_ha_resources"

rabbit_settings = fetch_rabbitmq_settings
transaction_objects = []

service_name = "ceilometer-central"
openstack_pacemaker_primitive service_name do
  agent node[:ceilometer][:ha][:central][:agent]
  op node[:ceilometer][:ha][:central][:op]
  action :update
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end
transaction_objects << "pacemaker_primitive[#{service_name}]"

location_name = openstack_pacemaker_controller_only_location_for service_name
transaction_objects << "pacemaker_location[#{location_name}]"

pacemaker_transaction "ceilometer central" do
  cib_objects transaction_objects
  # note that this will also automatically start the resources
  action :commit_new
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

crowbar_pacemaker_order_only_existing "o-#{service_name}" do
  ordering "( #{rabbit_settings[:pacemaker_resource]} cl-keystone ) #{service_name}"
  score "Optional"
  action :create
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

crowbar_pacemaker_sync_mark "create-ceilometer_central_ha_resources"
