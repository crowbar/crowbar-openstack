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

unless node[:cinder][:ha][:enabled]
  log "HA support for cinder is disabled"
  return
end

log "HA support for cinder is enabled"

cluster_admin_ip = CrowbarPacemakerHelper.cluster_vip(node, "admin")

include_recipe "crowbar-pacemaker::haproxy"

haproxy_loadbalancer "cinder-api" do
  address node[:cinder][:api][:bind_open_address] ? "0.0.0.0" : cluster_admin_ip
  port node[:cinder][:api][:bind_port]
  use_ssl (node[:cinder][:api][:protocol] == "https")
  servers CrowbarPacemakerHelper.haproxy_servers_for_service(node, "cinder", "cinder-controller", "api")
  rate_limit node[:cinder][:ha_rate_limit]["cinder-api"]
  action :nothing
end.run_action(:create)

if node[:pacemaker][:clone_stateless_services]
  # Wait for all nodes to reach this point so we know that all nodes will have
  # all the required packages installed before we create the pacemaker
  # resources
  crowbar_pacemaker_sync_mark "sync-cinder_before_ha"

  # Avoid races when creating pacemaker resources
  crowbar_pacemaker_sync_mark "wait-cinder_ha_resources"

  rabbit_settings = fetch_rabbitmq_settings
  services = ["api", "scheduler"]
  transaction_objects = []

  services.each do |service|
    primitive_name = "cinder-#{service}"

    objects = openstack_pacemaker_controller_clone_for_transaction primitive_name do
      agent node[:cinder][:ha]["#{service}_ra"]
      op node[:cinder][:ha][:op]
      order_only_existing "( postgresql #{rabbit_settings[:pacemaker_resource]} cl-keystone )"
    end
    transaction_objects.push(objects)
  end

  pacemaker_transaction "cinder controller" do
    cib_objects transaction_objects.flatten
    # note that this will also automatically start the resources
    action :commit_new
    only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end

  crowbar_pacemaker_sync_mark "create-cinder_ha_resources"
end
