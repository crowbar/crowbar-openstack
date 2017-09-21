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

haproxy_loadbalancer "swift-proxy" do
  address "0.0.0.0"
  port node[:swift][:ports][:proxy]
  use_ssl node[:swift][:ssl][:enabled]
  servers CrowbarPacemakerHelper.haproxy_servers_for_service(node, "swift", "swift-proxy", "proxy")
  action :nothing
end.run_action(:create)

if node[:pacemaker][:clone_stateless_services]
  # Wait for all nodes to reach this point so we know that all nodes will have
  # all the required packages installed before we create the pacemaker
  # resources
  crowbar_pacemaker_sync_mark "sync-swift_before_ha"

  # Avoid races when creating pacemaker resources
  crowbar_pacemaker_sync_mark "wait-swift_ha_resources" do
    only_if { ::File.exist? "/etc/swift/object.ring.gz" }
  end

  transaction_objects = []

  service_name = "swift-proxy"

  objects = openstack_pacemaker_controller_clone_for_transaction service_name do
    agent node[:swift][:ha]["proxy"][:agent]
    op node[:swift][:ha]["proxy"][:op]
    order_only_existing "cl-keystone"
  end
  transaction_objects.push(objects)

  pacemaker_transaction "swift proxy" do
    cib_objects transaction_objects.flatten
    # note that this will also automatically start the resources
    action :commit_new
    # Do not even try to start the daemon if we don't have the ring yet
    only_if {
      CrowbarPacemakerHelper.is_cluster_founder?(node) && ::File.exist?("/etc/swift/object.ring.gz")
    }
  end

  crowbar_pacemaker_sync_mark "create-swift_ha_resources" do
    only_if { ::File.exist? "/etc/swift/object.ring.gz" }
  end
end
