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

haproxy_loadbalancer "keystone-service" do
  address node[:keystone][:api][:api_host]
  port node[:keystone][:api][:service_port]
  use_ssl (node[:keystone][:api][:protocol] == "https")
  servers CrowbarPacemakerHelper.haproxy_servers_for_service(node, "keystone", "keystone-server", "service_port")
  action :nothing
end.run_action(:create)

haproxy_loadbalancer "keystone-admin" do
  address node[:keystone][:api][:admin_host]
  port node[:keystone][:api][:admin_port]
  use_ssl (node[:keystone][:api][:protocol] == "https")
  servers CrowbarPacemakerHelper.haproxy_servers_for_service(node, "keystone", "keystone-server", "admin_port")
  action :nothing
end.run_action(:create)

# Configure Keystone token fernet backend provider
if node[:keystone][:token_format] == "fernet"
  template "/usr/bin/keystone-fernet-keys-push.sh" do
    source "keystone-fernet-keys-push.sh"
    owner "root"
    group "root"
    mode "0755"
  end

  # To be sure that rsync package is installed
  package "rsync"
  crowbar_pacemaker_sync_mark "sync-keystone_install_rsync"

  rsync_command = ""
  initial_rsync_command = ""

  # can't use CrowbarPacemakerHelper.cluster_nodes() here as it will sometimes not return
  # nodes which will be added to the cluster in current chef-client run.
  cluster_nodes = node[:pacemaker][:elements]["pacemaker-cluster-member"]
  cluster_nodes = cluster_nodes.map { |n| Chef::Node.load(n) }
  cluster_nodes.sort_by! { |n| n[:hostname] }
  cluster_nodes.each do |n|
    next if node.name == n.name
    node_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(n, "admin").address
    node_rsync_command = "/usr/bin/keystone-fernet-keys-push.sh #{node_address}; "
    rsync_command += node_rsync_command
    # initial rsync only for (new) nodes which didn't get the keys yet
    next if n.include?(:keystone) &&
        n[:keystone][:initial_keys_sync]
    initial_rsync_command += node_rsync_command
  end
  raise "No other cluster members found" if rsync_command.empty?

  # Rotate primary key, which is used for new tokens
  template "/var/lib/keystone/keystone-fernet-rotate" do
    source "keystone-fernet-rotate.erb"
    owner "root"
    group node[:keystone][:group]
    mode "0750"
    variables(
      rsync_command: rsync_command
    )
  end

  crowbar_pacemaker_sync_mark "wait-keystone_fernet_rotate"

  if File.exist?("/etc/keystone/fernet-keys/0")
    # Mark node to avoid unneeded future rsyncs
    unless node[:keystone][:initial_keys_sync]
      node[:keystone][:initial_keys_sync] = true
      node.save
    end
  else
    # Setup a key repository for fernet tokens
    execute "keystone-manage fernet_setup" do
      command "keystone-manage fernet_setup \
        --keystone-user #{node[:keystone][:user]} \
        --keystone-group #{node[:keystone][:group]}"
      action :run
      only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
    end
  end

  # We would like to propagate fernet keys to all (new) nodes in the cluster
  execute "propagate fernet keys to all nodes in the cluster" do
    command initial_rsync_command
    action :run
    only_if do
      CrowbarPacemakerHelper.is_cluster_founder?(node) &&
        !initial_rsync_command.empty?
    end
  end

  service_transaction_objects = []

  keystone_fernet_primitive = "keystone-fernet-rotate"
  pacemaker_primitive keystone_fernet_primitive do
    agent node[:keystone][:ha][:fernet][:agent]
    params(
      "target" => "/var/lib/keystone/keystone-fernet-rotate",
      "link" => "/etc/cron.hourly/openstack-keystone-fernet",
      "backup_suffix" => ".orig"
    )
    op node[:keystone][:ha][:fernet][:op]
    action :update
    only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end
  service_transaction_objects << "pacemaker_primitive[#{keystone_fernet_primitive}]"

  fernet_rotate_loc = openstack_pacemaker_controller_only_location_for keystone_fernet_primitive
  service_transaction_objects << "pacemaker_location[#{fernet_rotate_loc}]"

  pacemaker_transaction "keystone-fernet-rotate cron" do
    cib_objects service_transaction_objects
    # note that this will also automatically start the resources
    action :commit_new
    only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end

  crowbar_pacemaker_sync_mark "create-keystone_fernet_rotate"
end

# note(jtomasiak): We don't need new syncmarks for the fernet-keys-sync part.
# This is because the deployment and configuration of this feature will be done
# once during keystone installation and it will not be used until some keystone
# node is reinstalled. We assume that time between keystone installation and
# possible node reinstallation is high enough to run this safely without
# syncmarks.
fernet_resources_action = node[:keystone][:token_format] == "fernet" ? :create : :delete

template "/usr/bin/keystone-fernet-keys-sync.sh" do
  source "keystone-fernet-keys-sync.sh"
  owner "root"
  group "root"
  mode "0755"
  action fernet_resources_action
end

# handler scripts are run by hacluster user so sudo configuration is needed
# if the handler needs to rsync to other nodes using root's keys
template "/etc/sudoers.d/keystone-fernet-keys-sync" do
  source "hacluster_sudoers.erb"
  owner "root"
  group "root"
  mode "0440"
  action fernet_resources_action
end

# on founder: create/delete pacemaker alert
pacemaker_alert "keystone-fernet-keys-sync" do
  handler "/usr/bin/keystone-fernet-keys-sync.sh"
  action fernet_resources_action
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

# Create/update apache resources after fernet keys setup to make sure everything is ready.
if node[:keystone][:frontend] == "apache" && node[:pacemaker][:clone_stateless_services]
  include_recipe "crowbar-pacemaker::apache"

  # Wait for all nodes to reach this point so we know that all nodes will have
  # all the required packages installed before we create the pacemaker
  # resources
  crowbar_pacemaker_sync_mark "sync-keystone_before_ha"

  # Avoid races when creating pacemaker resources
  crowbar_pacemaker_sync_mark "wait-keystone_ha_resources"

  rabbit_settings = fetch_rabbitmq_settings
  transaction_objects = []

  # let's create a dummy resource for keystone, that can be used for ordering
  # constraints (as the apache2 resource is too vague)
  objects = openstack_pacemaker_controller_clone_for_transaction "keystone" do
    agent "ocf:pacemaker:Dummy"
    order_only_existing "( postgresql #{rabbit_settings[:pacemaker_resource]} )"
  end
  transaction_objects.push(objects)

  order_name = "o-cl-apache2-keystone"
  pacemaker_order order_name do
    ordering "cl-apache2 cl-keystone"
    score "Mandatory"
    action :update
    only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end
  transaction_objects << "pacemaker_order[#{order_name}]"

  pacemaker_transaction "keystone server" do
    cib_objects transaction_objects.flatten
    # note that this will also automatically start the resources
    action :commit_new
    only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end

  crowbar_pacemaker_sync_mark "create-keystone_ha_resources"
end
