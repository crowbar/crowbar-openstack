# Copyright 2015 SUSE
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

unless node[:manila][:ha][:enabled]
  log "HA support for manila is disabled"
  return
end

log "HA support for manila is enabled"

cluster_admin_ip = CrowbarPacemakerHelper.cluster_vip(node, "admin")

include_recipe "crowbar-pacemaker::haproxy"

haproxy_loadbalancer "manila-api" do
  address node[:manila][:api][:bind_open_address] ?
    "0.0.0.0" : cluster_admin_ip
  port node[:manila][:api][:bind_port]
  use_ssl (node[:manila][:api][:protocol] == "https")
  servers CrowbarPacemakerHelper.haproxy_servers_for_service(node,
                                                             "manila",
                                                             "manila-server",
                                                             "api")
  action :nothing
end.run_action(:create)

if node[:pacemaker][:clone_stateless_services]
  include_recipe "crowbar-pacemaker::apache"

  # Wait for all nodes to reach this point so we know that all nodes will have
  # all the required packages installed before we create the pacemaker
  # resources
  crowbar_pacemaker_sync_mark "sync-manila_before_ha"

  # Avoid races when creating pacemaker resources
  crowbar_pacemaker_sync_mark "wait-manila_ha_resources"

  rabbit_settings = fetch_rabbitmq_settings
  transaction_objects = []

  order_name = "o-cl-apache2-manila-api"
  pacemaker_order order_name do
    ordering "cl-apache2 cl-manila-api"
    score "Mandatory"
    action :update
    only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end
  transaction_objects << "pacemaker_order[#{order_name}]"

  primitive_name = "manila-scheduler"

  objects = openstack_pacemaker_controller_clone_for_transaction primitive_name do
    agent node[:manila][:ha][:scheduler_ra]
    op node[:manila][:ha][:op]
    order_only_existing "( postgresql #{rabbit_settings[:pacemaker_resource]} cl-keystone " \
        "cl-glance-api cl-cinder-api cl-neutron-server cl-nova-api )"
  end
  transaction_objects.push(objects)

  pacemaker_transaction "manila controller" do
    cib_objects transaction_objects.flatten
    # note that this will also automatically start the resources
    action :commit_new
    only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end

  crowbar_pacemaker_sync_mark "create-manila_ha_resources"
end
