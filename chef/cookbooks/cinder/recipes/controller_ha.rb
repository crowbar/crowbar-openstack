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

haproxy_loadbalancer "cinder-api" do
  address node[:cinder][:api][:bind_open_address] ? "0.0.0.0" : node[:cinder][:api][:bind_host]
  port node[:cinder][:api][:bind_port]
  use_ssl (node[:cinder][:api][:protocol] == "https")
  servers CrowbarPacemakerHelper.haproxy_servers_for_service(node, "cinder", "cinder-controller", "api")
  action :nothing
end.run_action(:create)

# Wait for all nodes to reach this point so we know that all nodes will have
# all the required packages installed before we create the pacemaker
# resources
crowbar_pacemaker_sync_mark "sync-cinder_before_ha"

# Avoid races when creating pacemaker resources
crowbar_pacemaker_sync_mark "wait-cinder_ha_resources"

pacemaker_primitive "cinder-api" do
  agent node[:cinder][:ha][:api_ra]
  op node[:cinder][:ha][:op]
  action :create
end

pacemaker_primitive "cinder-scheduler" do
  agent node[:cinder][:ha][:scheduler_ra]
  op node[:cinder][:ha][:op]
  action :create
end

group_name = "g-cinder-controller"

pacemaker_group group_name do
  members ["cinder-api", "cinder-scheduler"]
  meta ({
    "is-managed" => true,
    "target-role" => "started"
  })
  action :create
end

pacemaker_clone "cl-#{group_name}" do
  rsc group_name
  action [:create, :start]
end

crowbar_pacemaker_sync_mark "create-cinder_ha_resources"
