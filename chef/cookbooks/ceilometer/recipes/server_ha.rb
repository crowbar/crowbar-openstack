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

haproxy_loadbalancer "ceilometer-api" do
  address "0.0.0.0"
  port node[:ceilometer][:api][:port]
  use_ssl (node[:ceilometer][:api][:protocol] == "https")
  servers CrowbarPacemakerHelper.haproxy_servers_for_service(node, "ceilometer", "ceilometer-server", "api")
  action :nothing
end.run_action(:create)

# setup the expirer cronjob only on a single node to not
# run into DB deadlocks (bsc#1113107)
crowbar_pacemaker_sync_mark "wait-ceilometer_expirer_cron"

expirer_transaction_objects = []

ceilometer_expirer_cron_primitive = "ceilometer-expirer-cron"
pacemaker_primitive ceilometer_expirer_cron_primitive do
  agent node[:ceilometer][:ha][:expirer][:cronjob][:agent]
  params(
    # target is from the RPM package openstack-ceilometer
    "target" => "/usr/share/ceilometer/openstack-ceilometer-expirer.cron",
    "link" => "/etc/cron.daily/openstack-ceilometer-expirer.cron",
    "backup_suffix" => ".orig"
  )
  op node[:ceilometer][:ha][:expirer][:cronjob][:op]
  action :update
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end
expirer_transaction_objects << "pacemaker_primitive[#{ceilometer_expirer_cron_primitive}]"

ceilometer_expirer_cron_loc = openstack_pacemaker_controller_only_location_for ceilometer_expirer_cron_primitive
expirer_transaction_objects << "pacemaker_location[#{ceilometer_expirer_cron_loc}]"

pacemaker_transaction "ceilometer-expirer cron" do
  cib_objects expirer_transaction_objects
  # note that this will also automatically start the resources
  action :commit_new
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

crowbar_pacemaker_sync_mark "create-ceilometer_expirer_cron"

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
