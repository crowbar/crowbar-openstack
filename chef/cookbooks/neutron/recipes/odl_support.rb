#
# Copyright 2016 SUSE LINUX GmbH
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

neutron = nil
if node.attribute?(:cookbook) && node[:cookbook] == "nova"
  neutrons = node_search_with_cache("roles:neutron-server", node[:nova][:neutron_instance])
  neutron = neutrons.first || raise("Neutron instance '#{node[:nova][:neutron_instance]}' \
                                    for nova not found")
else
  neutron = node
end

if node.roles.include?("neutron-server")
  node[:neutron][:platform][:odl_pkgs].each { |p| package p }
end

odl_nodes = node_search_with_cache("roles:opendaylight") 
odl_node = odl_nodes.first  || raise("No Opendaylight node found")

# Stop Neutron openvswitch agents on all nodes
service node[:neutron][:platform][:ovs_agent_name] do
  action [:disable, :stop]
end

# Stop L2 and L3 agents on the Controller
if node.roles.include?("neutron-network")
  Chef::Log.warn("Stopping L2 and L3 agent services")
  service node[:neutron][:platform][:dhcp_agent_name] do
    action [:disable, :stop]
  end
  service node[:neutron][:platform][:l3_agent_name] do
    action [:disable, :stop]
  end
end

# Prepare variables for switch setup for opendaylight controller
odl_controller_ip = neutron[:neutron][:odl][:controller_ip]
odl_manager_port = neutron[:neutron][:odl][:manager_port]
odl_protocol = neutron[:neutron][:odl][:protocol]

ovs_manager = "tcp:#{odl_controller_ip}:#{odl_manager_port}"
odl_api_port = odl_node[:opendaylight][:port]

# Delete old bridge controllers if they are assigned.
["br-int", "br-tunnel", "br-fixed", "br-public"].each do |bridge|
  execute "delete_bridge_controllers" do
    command "ovs-vsctl del-controller #{bridge}"
    action :run
    not_if "out=$(ovs-vsctl br-exists #{bridge}); [ $? != 0 ]"
  end
end

# Delete bridges to allow ODL to create and patch them
["br-int", "br-tunnel", "br-fixed", "br-public"].each do |bridge|
  execute "delete_bridges" do
    command "ovs-vsctl del-br #{bridge}"
    action :run
    not_if "out=$(ovs-vsctl br-exists #{bridge}); [ $? != 0 ]"
  end
end

# Delete ports if already exists
["br-fixed", "br-public"].each do |bridge|
  execute "delete_fixed_public_ports" do
    command "ovs-vsctl del-port br-int #{bridge}"
    action :run
    not_if "out=$(ovs-vsctl br-exists #{bridge}); [ $? != 0 ]"
  end
end

# Create br-fixed and br-public for ODL to patch
["br-fixed", "br-public"].each do |bridge|
  execute "create_fixed_public_bridges" do
    command "ovs-vsctl --may-exist add-br #{bridge}"
    action :run
  end
end

bash "update_ovs_switches" do
  user "root"
  action :run
  code <<-EOF
    ovs_id=$(ovs-vsctl show | head -1) 
    mappings="physnet1:br-fixed,physnet2:br-public"
    local_ip=$(ifconfig eth0 | grep "inet addr" | awk '{print $2}' | awk -F':' '{print $2}')
    ovs-vsctl set Open_vSwitch $ovs_id other_config={local_ip=$local_ip}
    ovs-vsctl set Open_vSwitch $ovs_id other_config:provider_mappings=$mappings

    # After setting the manager path and restart openvswitch, ODL does the following:
    #   - Creates br-int
    #   - Creates patch ports for br-fixed and br-public and patches them to br-int
    #   - Sets ODL controller as the controller for all the bridges.
    #   - Adds NORMAL flows to br-fixed and br-public and several useful flows on br-int
    # Short sleep to ensure bridges are setup before the manager is configured.
    ovs-vsctl del-manager
    sleep 5
    ovs-vsctl set-manager #{ovs_manager}
    service openvswitch restart
  EOF
end

if node.roles.include?("neutron-server")
  # Required as workaround for OpenStack Newton
  template "/etc/neutron/dhcp_agent.ini" do
    cookbook "neutron"
    source "dhcp_agent.ini.erb"
    mode "0640"
    owner "root"
    group node[:neutron][:platform][:group]
    variables(
      force_metadata: true,
      ovsdb_interface: "vsctl"
    )
    notifies :restart, "service[#{node[:neutron][:platform][:service_name]}]" 
  end


  odl_url = "#{odl_protocol}://#{odl_controller_ip}:#{odl_api_port}/controller/nb/v2/neutron"
  template "/etc/neutron/neutron-server.conf.d/100-ml2_conf_odl.ini.conf" do
    cookbook "neutron"
    source "ml2_conf_odl.ini.erb"
    mode "0640"
    owner "root"
    group node[:neutron][:platform][:group]
    variables(
      ml2_odl_url: odl_url,
      ml2_odl_username: node[:neutron][:odl][:username],
      ml2_odl_password: node[:neutron][:odl][:password]
    )
    notifies :restart, "service[#{node[:neutron][:platform][:service_name]}]"
  end

  # (mmnelemane): May revisit include the below configs when working with l3-router
  # Need to add the new parameters in dhcp_agent.ini.erb if this is enabled.
  # neutron_options = "--config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/ml2/ml2_conf.ini"
  # execute "neutron_db_sync" do
  #   command "neutron-db-manage #{neutron_options} upgrade head"
  #   action :run
  #   notifies :restart, "service[#{node[:neutron][:platform][:service_name]}]"
  # end

  # l3_router = ["odl-router"]
  # template "/etc/neutron/neutron.conf" do
  #  source "neutron.conf.erb"
  #  variables(
  #    service_plugins: l3_router
  #  )
  #  notifies :restart, "service[#{node[:neutron][:platform][:service_name]}]"
  # end
end
