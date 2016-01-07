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

package node[:neutron][:platform][:ha_tool_pkg] unless node[:neutron][:platform][:ha_tool_pkg] == ""

use_l3_agent = (node[:neutron][:networking_plugin] != "vmware")
use_lbaas_agent = node[:neutron][:use_lbaas]

# Wait for all "neutron-network" nodes to reach this point so we know that they will
# have all the required packages installed and configuration files updated
# before we create the pacemaker resources.
crowbar_pacemaker_sync_mark "sync-neutron-agents_before_ha"

# Avoid races when creating pacemaker resources
crowbar_pacemaker_sync_mark "wait-neutron-agents_ha_resources" do
  timeout 180
end

group_members = []
transaction_objects = []

if use_l3_agent
  l3_agent_primitive = "neutron-l3-agent"
  pacemaker_primitive l3_agent_primitive do
    agent node[:neutron][:ha][:network][:l3_ra]
    op node[:neutron][:ha][:network][:op]
    action :update
    only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end
  group_members << l3_agent_primitive
  transaction_objects << "pacemaker_primitive[#{l3_agent_primitive}]"
end

dhcp_agent_primitive = "neutron-dhcp-agent"
pacemaker_primitive dhcp_agent_primitive do
  agent node[:neutron][:ha][:network][:dhcp_ra]
  op node[:neutron][:ha][:network][:op]
  action :update
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end
group_members << dhcp_agent_primitive
transaction_objects << "pacemaker_primitive[#{dhcp_agent_primitive}]"

metadata_agent_primitive = "neutron-metadata-agent"
pacemaker_primitive metadata_agent_primitive do
  agent node[:neutron][:ha][:network][:metadata_ra]
  op node[:neutron][:ha][:network][:op]
  action :update
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end
group_members << metadata_agent_primitive
transaction_objects << "pacemaker_primitive[#{metadata_agent_primitive}]"

metering_agent_primitive = "neutron-metering-agent"
pacemaker_primitive metering_agent_primitive do
  agent node[:neutron][:ha][:network][:metering_ra]
  op node[:neutron][:ha][:network][:op]
  action :update
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end
group_members << metering_agent_primitive
transaction_objects << "pacemaker_primitive[#{metering_agent_primitive}]"

if use_lbaas_agent
  lbaas_agent_primitive = "neutron-lbaas-agent"
  pacemaker_primitive lbaas_agent_primitive do
    agent node[:neutron][:ha][:network][:lbaas_ra]
    op node[:neutron][:ha][:network][:op]
    action :update
    only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end
  group_members << lbaas_agent_primitive
  transaction_objects << "pacemaker_primitive[#{lbaas_agent_primitive}]"
end

if use_l3_agent
  case node[:neutron][:networking_plugin]
  when "ml2"
    ml2_mech_drivers = node[:neutron][:ml2_mechanism_drivers]
    case
    when ml2_mech_drivers.include?("openvswitch")
      neutron_agent = node[:neutron][:platform][:ovs_agent_name]
      neutron_agent_ra = node[:neutron][:ha][:network]["openvswitch_ra"]
    when ml2_mech_drivers.include?("linuxbridge")
      neutron_agent = node[:neutron][:platform][:lb_agent_name]
      neutron_agent_ra = node[:neutron][:ha][:network]["linuxbridge_ra"]
    end
  when "vmware"
    neutron_agent = ""
    neutron_agent_ra = ""
  end
  neutron_agent_primitive = neutron_agent.sub(/^openstack-/, "")

  pacemaker_primitive neutron_agent_primitive do
    agent neutron_agent_ra
    op node[:neutron][:ha][:network][:op]
    action :update
    only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end
  group_members << neutron_agent_primitive
  transaction_objects << "pacemaker_primitive[#{neutron_agent_primitive}]"
end

agents_group_name = "g-neutron-agents"
pacemaker_group agents_group_name do
  members group_members
  action :update
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end
transaction_objects << "pacemaker_group[#{agents_group_name}]"

agents_clone_name = "cl-#{agents_group_name}"
pacemaker_clone agents_clone_name do
  rsc agents_group_name
  action :update
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end
transaction_objects << "pacemaker_clone[#{agents_clone_name}]"

pacemaker_transaction "neutron agents" do
  cib_objects transaction_objects
  # note that this will also automatically start the resources
  action :commit_new
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)
# FIXME: neutron-ha-tool can't do keystone v3 currently
os_auth_url_v2 = KeystoneHelper.versioned_service_URL(keystone_settings["protocol"],
                                                       keystone_settings["internal_url_host"],
                                                       keystone_settings["service_port"],
                                                       "2.0")

ha_tool_primitive_name = "neutron-ha-tool"

# FIXME: While the neutron-ha-tool resource agent allows specifying a CA
# Certificate to use for SSL Certificate verification, it's hard to select
# right CA file as we allow Keystone's and Neutron's to use different CAs.  So
# we just rely on the correct CA files being installed in a system wide default
# location.
file "/etc/neutron/os_password" do
  owner "root"
  group "root"
  mode "0600"
  content keystone_settings["admin_password"]
  # Our Chef is apparently too old for this :-/
  #sensitive true
  action :create
end

pacemaker_primitive ha_tool_primitive_name do
  agent node[:neutron][:ha][:network][:ha_tool_ra]
  params ({
    "os_auth_url"    => os_auth_url_v2,
    "os_region_name" => keystone_settings["endpoint_region"],
    "os_tenant_name" => keystone_settings["admin_tenant"],
    "os_username"    => keystone_settings["admin_user"],
    "os_insecure"    => keystone_settings["insecure"] || node[:neutron][:ssl][:insecure]
  })
  op node[:neutron][:ha][:network][:op]
  action [:create, :start]
  only_if { use_l3_agent && CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

crowbar_pacemaker_order_only_existing "o-#{ha_tool_primitive_name}" do
  ordering ["g-haproxy", "cl-neutron-server", agents_clone_name, ha_tool_primitive_name]
  score "Mandatory"
  action :create
  only_if { use_l3_agent && CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

crowbar_pacemaker_sync_mark "create-neutron-agents_ha_resources"
