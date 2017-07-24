# Copyright 2016 SUSE
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

remote_nodes = CrowbarPacemakerHelper.remote_nodes(node)
return if remote_nodes.empty?

nova = remote_nodes.first
unless nova.roles.any? { |role| /^nova-compute-/ =~ role }
  Chef::Log.info("Skipping setup of HA for compute nodes as remote nodes don't have a nova compute role yet.")
  return
end

unless nova[:nova][:ha][:compute][:enabled]
  raise "HA for compute nodes is not enabled!"
end

unless nova[:nova][:ha][:compute][:setup]
  Chef::Log.info("Skipping setup of HA for compute nodes as compute nodes have not been prepared yet.")
  return
end

keystone_settings = KeystoneHelper.keystone_settings(nova, @cookbook_name)
neutrons = search(:node, "roles:neutron-server AND roles:neutron-config-#{nova[:nova][:neutron_instance]}")
neutron = neutrons.first || \
  raise("Neutron instance '#{nova[:nova][:neutron_instance]}' for nova not found")

no_shared_storage = nova[:nova]["use_shared_instance_storage"] ? "0" : "1"

# Install basic nova package to have /var/log/nova (used by fence_compute) as
# well as nova user (to not have some weird permissions in /var/log/nova in
# case nova is installed later)
package "nova-common" do
  if %w(rhel suse).include?(node[:platform_family])
    package_name "openstack-nova"
  end
end

# We have to install libvirt and neutron packages on the corosync nodes so that
# pacemaker can know about the resource agents.
package "libvirt"

case neutron[:neutron][:networking_plugin]
when "ml2"
  ml2_mech_drivers = neutron[:neutron][:ml2_mechanism_drivers]
  case
  when ml2_mech_drivers.include?("openvswitch")
    neutron_agent = neutron[:neutron][:platform][:ovs_agent_name]
    neutron_agent_pkg = neutron[:neutron][:platform][:ovs_agent_pkg]
    neutron_agent_ra = neutron[:neutron][:ha][:network]["openvswitch_ra"]
  when ml2_mech_drivers.include?("linuxbridge")
    neutron_agent = neutron[:neutron][:platform][:lb_agent_name]
    neutron_agent_pkg = neutron[:neutron][:platform][:lb_agent_pkg]
    neutron_agent_ra = neutron[:neutron][:ha][:network]["linuxbridge_ra"]
  when ml2_mech_drivers.include?("cisco_apic_ml2") || ml2_mech_drivers.include?("apic_gbp")
    neutron_agent = ""
    neutron_agent_pkg = ""
    neutron_agent_ra = ""
  end

  package neutron_agent_pkg unless neutron_agent_ra.empty?
end

if neutron[:neutron][:use_dvr]
  package neutron[:neutron][:platform][:l3_agent_pkg]
  package neutron[:neutron][:platform][:metadata_agent_pkg]
end

# Wait for all nodes to reach this point so we know that all nodes will have
# all the required packages installed before we create the pacemaker
# resources.
# We use the revision of the nova node we found as the goal is to not require
# the corosync nodes to be part of the nova proposal.
crowbar_pacemaker_sync_mark "sync-nova_compute_before_ha" do
  revision nova[:nova]["crowbar-revision"]
end

# Avoid races when creating pacemaker resources
crowbar_pacemaker_sync_mark "wait-nova_compute_ha_resources" do
  revision nova[:nova]["crowbar-revision"]
end

compute_primitives = []
compute_transaction_objects = []

libvirtd_primitive = "libvirtd-compute"
pacemaker_primitive libvirtd_primitive do
  agent "systemd:libvirtd"
  op nova[:nova][:ha][:op]
  action :update
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end
compute_primitives << libvirtd_primitive
compute_transaction_objects << "pacemaker_primitive[#{libvirtd_primitive}]"

case neutron[:neutron][:networking_plugin]
when "ml2"
  # neutron_agent & neutron_agent_ra are empty for plugins like cisco_apic_ml2 and apic_gbp
  unless neutron_agent.empty? || neutron_agent_ra.empty?
    neutron_agent_primitive = "#{neutron_agent.sub(/^openstack-/, "")}-compute"
    pacemaker_primitive neutron_agent_primitive do
      agent neutron_agent_ra
      op neutron[:neutron][:ha][:network][:op]
      action :update
      only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
    end
    compute_primitives << neutron_agent_primitive
    compute_transaction_objects << "pacemaker_primitive[#{neutron_agent_primitive}]"
  end
end

if neutron[:neutron][:use_dvr]
  l3_agent_primitive = "neutron-l3-agent-compute"
  pacemaker_primitive l3_agent_primitive do
    agent neutron[:neutron][:ha][:network][:l3_ra]
    op neutron[:neutron][:ha][:network][:op]
    action :update
    only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end
  compute_primitives << l3_agent_primitive
  compute_transaction_objects << "pacemaker_primitive[#{l3_agent_primitive}]"

  metadata_agent_primitive = "neutron-metadata-agent-compute"
  pacemaker_primitive metadata_agent_primitive do
    agent neutron[:neutron][:ha][:network][:metadata_ra]
    op neutron[:neutron][:ha][:network][:op]
    action :update
    only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end
  compute_primitives << metadata_agent_primitive
  compute_transaction_objects << "pacemaker_primitive[#{metadata_agent_primitive}]"
end

nova_primitive = "nova-compute"
pacemaker_primitive nova_primitive do
  agent "ocf:openstack:NovaCompute"
  params ({
    "auth_url"       => keystone_settings["internal_auth_url"],
    # "region_name"    => keystone_settings["endpoint_region"],
    "endpoint_type"  => "internalURL",
    "username"       => keystone_settings["admin_user"],
    "password"       => keystone_settings["admin_password"],
    "tenant_name"    => keystone_settings["admin_tenant"],
    # "insecure"       => keystone_settings["insecure"] || nova[:nova][:ssl][:insecure],
    "domain"         => node[:domain],
    "no_shared_storage" => no_shared_storage
  })
  op nova[:nova][:ha][:compute][:compute][:op]
  action :update
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end
compute_primitives << nova_primitive
compute_transaction_objects << "pacemaker_primitive[#{nova_primitive}]"

compute_group_name = "g-#{nova_primitive}"
pacemaker_group compute_group_name do
  members compute_primitives
  action :update
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end
compute_transaction_objects << "pacemaker_group[#{compute_group_name}]"

compute_clone_name = "cl-#{compute_group_name}"
pacemaker_clone compute_clone_name do
  rsc compute_group_name
  meta ({
    "clone-max" => CrowbarPacemakerHelper.num_remote_nodes(node),
    "interleave" => "true",
  })
  action :update
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end
compute_transaction_objects << "pacemaker_clone[#{compute_clone_name}]"

compute_location_name = "l-#{compute_clone_name}-compute"
pacemaker_location compute_location_name do
  definition OpenStackHAHelper.compute_only_location(compute_location_name, compute_clone_name)
  action :update
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end
compute_transaction_objects << "pacemaker_location[#{compute_location_name}]"

pacemaker_transaction "nova compute" do
  cib_objects compute_transaction_objects
  # note that this will also automatically start the resources
  action :commit_new
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

controller_transaction_objects = []

evacuate_primitive = "nova-evacuate"
pacemaker_primitive evacuate_primitive do
  agent "ocf:openstack:NovaEvacuate"
  params ({
    "auth_url"       => keystone_settings["internal_auth_url"],
    # "region_name"    => keystone_settings["endpoint_region"],
    "endpoint_type"  => "internalURL",
    "username"       => keystone_settings["admin_user"],
    "password"       => keystone_settings["admin_password"],
    "tenant_name"    => keystone_settings["admin_tenant"],
    # "insecure"       => keystone_settings["insecure"] || nova[:nova][:ssl][:insecure],
    "domain"         => node[:domain],
    "no_shared_storage" => no_shared_storage
  })
  op nova[:nova][:ha][:compute][:evacuate][:op]
  action :update
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end
controller_transaction_objects << "pacemaker_primitive[#{evacuate_primitive}]"

controller_location_name = "l-#{evacuate_primitive}-controller"
pacemaker_location controller_location_name do
  definition OpenStackHAHelper.no_compute_location(controller_location_name, evacuate_primitive)
  action :update
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end
controller_transaction_objects << "pacemaker_location[#{controller_location_name}]"

order_name = "o-#{compute_clone_name}"
pacemaker_order order_name do
  score "Mandatory"
  ordering "#{compute_clone_name} #{evacuate_primitive}"
  action :update
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end
controller_transaction_objects << "pacemaker_order[#{order_name}]"

hostmap = remote_nodes.map do |remote_node|
  "remote-#{remote_node[:hostname]}:#{remote_node[:hostname]}"
end.sort.join(";")

fence_primitive = "fence-nova"
pacemaker_primitive fence_primitive do
  agent "stonith:fence_compute"
  params ({
    "pcmk_host_map"  => hostmap,
    "auth-url"       => keystone_settings["internal_auth_url"],
    # "region-name"    => keystone_settings["endpoint_region"],
    "endpoint-type"  => "internalURL",
    "login"          => keystone_settings["admin_user"],
    "passwd"         => keystone_settings["admin_password"],
    "tenant-name"    => keystone_settings["admin_tenant"],
    # "insecure"       => keystone_settings["insecure"] || nova[:nova][:ssl][:insecure],
    "domain"         => node[:domain],
    "no-shared-storage" => no_shared_storage,
    "record-only"    => "1",
    "verbose"        => "1",
    "debug"          => "/var/log/nova/fence_compute.log"
  })
  op nova[:nova][:ha][:compute][:fence][:op]
  action :update
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end
controller_transaction_objects << "pacemaker_primitive[#{fence_primitive}]"

pacemaker_transaction "nova compute (non-remote bits)" do
  cib_objects controller_transaction_objects
  # note that this will also automatically start the resources
  action :commit_new
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

unless %w(disabled manual).include? node[:pacemaker][:stonith][:mode]
  case node[:pacemaker][:stonith][:mode]
  when "sbd"
    stonith_resource = "stonith-sbd"
  when "shared"
    stonith_resource = "stonith-shared"
  when "per_node"
    stonith_resource = nil
  else
    raise "Unknown STONITH mode: #{node[:pacemaker][:stonith][:mode]}."
  end

  topology = remote_nodes.map do |remote_node|
    remote_stonith = stonith_resource
    remote_stonith ||= "stonith-remote-#{remote_node[:hostname]}"
    "remote-#{remote_node[:hostname]}: #{remote_stonith},#{fence_primitive}"
  end

  # TODO: implement proper LWRP for this, and move this as part of the
  # transaction for controller bits
  bash "crm configure fencing_topology" do
    code "echo fencing_topology #{topology.sort.join(" ")} | crm configure load update -"
  end
end

crowbar_pacemaker_order_only_existing "o-#{evacuate_primitive}" do
  # We need services required to boot an instance; most of these services are
  # obviously required. Some additional notes:
  #  - swift is used in case it's the backend for glance
  #  - cinder is used in case of boot from volume
  #  - neutron agents are used even with DVR, if only to have a DHCP server for
  #    the instance to get an IP address
  ordering "( postgresql rabbitmq cl-keystone cl-swift-proxy cl-g-glance cl-g-cinder-controller cl-neutron-server cl-g-neutron-agents cl-g-nova-controller ) #{evacuate_primitive}"
  score "Mandatory"
  action :create
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

crowbar_pacemaker_sync_mark "create-nova_compute_ha_resources" do
  revision nova[:nova]["crowbar-revision"]
end
