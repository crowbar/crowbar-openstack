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

if node[:pacemaker][:clone_stateless_services]
  # Wait for all nodes to reach this point so we know that they will have
  # all the required packages installed and configuration files updated
  # before we create the pacemaker resources.
  crowbar_pacemaker_sync_mark "sync-ceilometer_server_before_ha"

  # Avoid races when creating pacemaker resources
  crowbar_pacemaker_sync_mark "wait-ceilometer_server_ha_resources"

  rabbit_settings = fetch_rabbitmq_settings
  services = ["agent_notification"]
  transaction_objects = []

  services.each do |service|
    primitive_name = "ceilometer-#{service}"

    # we don't make the db mandatory if not mongodb; this is debatable, but
    # oslo.db is supposed to deal well with reconnections; it's less clear about
    # mongodb
    order_only_existing = "( postgresql #{rabbit_settings[:pacemaker_resource]} cl-keystone )"

    objects = openstack_pacemaker_controller_clone_for_transaction primitive_name do
      agent node[:ceilometer][:ha][service.to_sym][:agent]
      op node[:ceilometer][:ha][service.to_sym][:op]
      order_only_existing order_only_existing
    end
    transaction_objects.push(objects)
  end

  pacemaker_transaction "ceilometer server" do
    cib_objects transaction_objects.flatten
    # note that this will also automatically start the resources
    action :commit_new
    only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end

  crowbar_pacemaker_sync_mark "create-ceilometer_server_ha_resources"

  include_recipe "crowbar-pacemaker::apache"
end
