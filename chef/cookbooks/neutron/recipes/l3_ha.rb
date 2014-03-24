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

package node[:neutron][:platform][:ha_tool_pkg]

use_l3_agent = (node[:neutron][:networking_plugin] != "vmware")
pacemaker_primitive node[:neutron][:platform][:l3_agent_name] do
  agent node[:neutron][:ha][:l3][:l3_ra]
  op node[:neutron][:ha][:l3][:op]
  action [ :create ]
  retries 1
  retry_delay 5
  only_if { use_l3_agent }
end

pacemaker_primitive node[:neutron][:platform][:dhcp_agent_name] do
  agent node[:neutron][:ha][:l3][:dhcp_ra]
  op node[:neutron][:ha][:l3][:op]
  action [ :create ]
  retries 1
  retry_delay 5
end

pacemaker_primitive node[:neutron][:platform][:metadata_agent_name] do
  agent node[:neutron][:ha][:l3][:metadata_ra]
  op node[:neutron][:ha][:l3][:op]
  action [ :create ]
  retries 1
  retry_delay 5
end

pacemaker_primitive node[:neutron][:platform][:metering_agent_name] do
  agent node[:neutron][:ha][:l3][:metering_ra]
  op node[:neutron][:ha][:l3][:op]
  action [ :create ]
  retries 1
  retry_delay 5
end

networking_plugin = node[:neutron][:networking_plugin]
case networking_plugin
when "openvswitch", "cisco"
  neutron_agent = node[:neutron][:platform][:ovs_agent_name]
when "linuxbridge"
  neutron_agent = node[:neutron][:platform][:lb_agent_name]
when "vmware"
  neutron_agent = node[:neutron][:platform][:nvp_agent_name]
end

pacemaker_primitive neutron_agent do
  agent node[:neutron][:ha][:l3]["#{networking_plugin}_ra"]
  op node[:neutron][:ha][:l3][:op]
  action [ :create ]
  retries 1
  retry_delay 5
end

group_members = []
group_members << node[:neutron][:platform][:l3_agent_name] if use_l3_agent
group_members += [ node[:neutron][:platform][:dhcp_agent_name],
                   node[:neutron][:platform][:metadata_agent_name],
                   node[:neutron][:platform][:metering_agent_name],
                   neutron_agent ]

pacemaker_group "group-neutron-agents" do
  members group_members
  meta ({
    "is-managed" => true,
    "target-role" => "started"
  })
  action [ :create ]
  retries 1
  retry_delay 5
end

pacemaker_clone "clone-neutron-agents" do
  rsc "group-neutron-agents"
  action [ :create, :start ]
end

keystone_settings = NeutronHelper.keystone_settings(node)

pacemaker_primitive "neutron-ha-tool" do
  agent node[:neutron][:ha][:l3][:ha_tool_ra]
  params ({
    "os_auth_url"    => keystone_settings["internal_auth_url"],
    "os_tenant_name" => keystone_settings["admin_tenant"],
    "os_username"    => keystone_settings["admin_user"],
    "os_password"    => keystone_settings["admin_password"]
  })
  op node[:neutron][:ha][:l3][:op]
  action [ :create, :start ]
  retries 1
  retry_delay 5
  only_if { use_l3_agent }
end

pacemaker_order "neutron-ha-tool_after_clone-neutron-agents" do
  ordering "clone-neutron-agents neutron-ha-tool"
  score "Mandatory"
  action [ :create ]
  only_if { use_l3_agent }
end
