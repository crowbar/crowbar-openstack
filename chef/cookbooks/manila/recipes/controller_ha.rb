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

cluster_vhostname = CrowbarPacemakerHelper.cluster_vhostname(node)

admin_net_db = Chef::DataBagItem.load("crowbar", "admin_network").raw_data
cluster_admin_ip = admin_net_db["allocated_by_name"]["#{cluster_vhostname}.#{node[:domain]}"]["address"]

haproxy_loadbalancer "manila-api" do
  address node[:manila][:api][:bind_open_address] ?
    "0.0.0.0" : cluster_admin_ip
  port node[:manila][:api][:bind_port]
  # FIXME(toabctl): implement SSL support
  # use_ssl (node[:manila][:api][:protocol] == "https")
  use_ssl false
  servers CrowbarPacemakerHelper.haproxy_servers_for_service(node,
                                                             "manila",
                                                             "manila-server",
                                                             "api")
  action :nothing
end.run_action(:create)

# Wait for all nodes to reach this point so we know that all nodes will have
# all the required packages installed before we create the pacemaker
# resources
crowbar_pacemaker_sync_mark "sync-manila_before_ha"

# Avoid races when creating pacemaker resources
crowbar_pacemaker_sync_mark "wait-manila_ha_resources"

pacemaker_primitive "manila-api" do
  agent node[:manila][:ha][:api_ra]
  op node[:manila][:ha][:op]
  action :create
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

pacemaker_primitive "manila-scheduler" do
  agent node[:manila][:ha][:scheduler_ra]
  op node[:manila][:ha][:op]
  action :create
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

group_name = "g-manila-controller"

pacemaker_group group_name do
  members ["manila-api", "manila-scheduler"]
  action :create
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

pacemaker_clone "cl-#{group_name}" do
  rsc group_name
  action [:create, :start]
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

crowbar_pacemaker_order_only_existing "o-cl-#{group_name}" do
  ordering ["postgresql", "rabbitmq", "cl-keystone", "cl-glance", "cl-cinder",
            "cl-neutron", "cl-nova", "cl-#{group_name}"]
  score "Optional"
  action :create
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

crowbar_pacemaker_sync_mark "create-manila_ha_resources"
