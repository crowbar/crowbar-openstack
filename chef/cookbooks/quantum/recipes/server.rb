# Copyright 2011 Dell, Inc.
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

unless node[:quantum][:use_gitrepo]
  case node[:quantum][:networking_plugin]
  when "openvswitch"
    plugin_cfg_path = "/etc/quantum/plugins/openvswitch/ovs_quantum_plugin.ini"
  when "linuxbridge"
    plugin_cfg_path = "/etc/quantum/plugins/linuxbridge/linuxbridge_conf.ini"
  end
  pkgs = node[:quantum][:platform][:pkgs]
  pkgs.each { |p| package p }
  file "/etc/default/quantum-server" do
    action :delete
    not_if { node[:platform] == "suse" }
    notifies :restart, "service[#{node[:quantum][:platform][:service_name]}]"
  end
  template "/etc/sysconfig/quantum" do
    source "suse.sysconfig.quantum.erb"
    owner "root"
    group "root"
    mode 0640
    variables(
      :plugin_config_file => plugin_cfg_path
    )
    only_if { node[:platform] == "suse" }
    notifies :restart, "service[#{node[:quantum][:platform][:service_name]}]"
  end
else
  quantum_service_name="quantum-server"
  quantum_path = "/opt/quantum"
  venv_path = node[:quantum][:use_virtualenv] ? "#{quantum_path}/.venv" : nil

  link_service "quantum-server" do
    virtualenv venv_path
    bin_name "quantum-server --config-dir /etc/quantum/"
  end
  link_service "quantum-dhcp-agent" do
    virtualenv venv_path
    bin_name "quantum-dhcp-agent --config-dir /etc/quantum/"
  end
  link_service "quantum-l3-agent" do
    virtualenv venv_path
    bin_name "quantum-l3-agent --config-dir /etc/quantum/"
  end
  link_service "quantum-metadata-agent" do
    virtualenv venv_path
    bin_name "quantum-metadata-agent --config-dir /etc/quantum/ --config-file /etc/quantum/metadata_agent.ini"
  end
end

include_recipe "quantum::database"
include_recipe "quantum::api_register"
include_recipe "quantum::common_install"

# Kill all the libvirt default networks.
execute "Destroy the libvirt default network" do
  command "virsh net-destroy default"
  only_if "virsh net-list |grep default"
end

link "/etc/libvirt/qemu/networks/autostart/default.xml" do
  action :delete
end


env_filter = " AND keystone_config_environment:keystone-config-#{node[:quantum][:keystone_instance]}"
keystones = search(:node, "recipes:keystone\\:\\:server#{env_filter}") || []
if keystones.length > 0
  keystone = keystones[0]
  keystone = node if keystone.name == node.name
else
  keystone = node
end

keystone_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(keystone, "admin").address if keystone_address.nil?
keystone_protocol = keystone["keystone"]["api"]["protocol"]
keystone_service_port = keystone["keystone"]["api"]["service_port"]
keystone_admin_port = keystone["keystone"]["api"]["admin_port"]
keystone_service_tenant = keystone["keystone"]["service"]["tenant"]
keystone_service_user = node["quantum"]["service_user"]
keystone_service_password = node["quantum"]["service_password"]
keystone_service_url = "#{keystone_protocol}://#{keystone_address}:#{keystone_admin_port}/v2.0"
Chef::Log.info("Keystone server found at #{keystone_address}")

template "/etc/quantum/api-paste.ini" do
  source "api-paste.ini.erb"
  owner node[:quantum][:platform][:user]
  group "root"
  mode "0640"
  variables(
    :keystone_protocol => keystone_protocol,
    :keystone_ip_address => keystone_address,
    :keystone_service_port => keystone_service_port,
    :keystone_service_tenant => keystone_service_tenant,
    :keystone_service_user => keystone_service_user,
    :keystone_service_password => keystone_service_password,
    :keystone_admin_port => keystone_admin_port
  )
end

case node[:quantum][:networking_plugin]
when "openvswitch"
  interface_driver = "quantum.agent.linux.interface.OVSInterfaceDriver"
when "linuxbridge"
  interface_driver = "quantum.agent.linux.interface.BridgeInterfaceDriver"
end

# Hardcode for now.
template "/etc/quantum/l3_agent.ini" do
  source "l3_agent.ini.erb"
  owner node[:quantum][:platform][:user]
  group "root"
  mode "0640"
  variables(
    :debug => node[:quantum][:debug],
    :interface_driver => interface_driver,
    :use_namespaces => "True",
    :handle_internal_only_routers => "True",
    :metadata_port => 9697,
    :send_arp_for_ha => 3,
    :periodic_interval => 40,
    :periodic_fuzzy_delay => 5
  )
end

dns_list = node[:dns][:forwarders].join(" ")

# Ditto
template "/etc/quantum/dhcp_agent.ini" do
  source "dhcp_agent.ini.erb"
  owner node[:quantum][:platform][:user]
  group "root"
  mode "0640"
  variables(
    :debug => node[:quantum][:debug],
    :interface_driver => interface_driver,
    :use_namespaces => "True",
    :resync_interval => 5,
    :dhcp_driver => "quantum.agent.linux.dhcp.Dnsmasq",
    :enable_isolated_metadata => "True",
    :enable_metadata_network => "True",
    :nameservers => dns_list
  )
end

# Double ditto.

novas = search(:node, "roles:nova-multi-controller") || []
if novas.length > 0
  nova = novas[0]
  nova = node if nova.name == node.name
else
  nova = node
end
metadata_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(nova, "public").address rescue nil
metadata_port = "8775"

template "/etc/quantum/metadata_agent.ini" do
  source "metadata_agent.ini.erb"
  owner node[:quantum][:platform][:user]
  group "root"
  mode "0640"
  variables(
    :debug => node[:quantum][:debug],
    :auth_url => keystone_service_url,
    :auth_region => "RegionOne",
    :admin_tenant_name => keystone_service_tenant,
    :admin_user => keystone_service_user,
    :admin_password => keystone_service_password,
    :nova_metadata_port => metadata_port,
    :nova_metadata_ip => metadata_address,
    :metadata_shared_secret => "Secret"
  )
end

service node[:quantum][:platform][:metadata_agent_name] do
  supports :status => true, :restart => true
  action :enable
  subscribes :restart, resources("template[/etc/quantum/quantum.conf]")
  subscribes :restart, resources("template[/etc/quantum/metadata_agent.ini]")
end

case node[:quantum][:networking_plugin]
when "openvswitch"
  directory "/etc/quantum/plugins/openvswitch/" do
     mode 00775
     owner node[:quantum][:platform][:user]
     action :create
     recursive true
     not_if { node[:platform] == "suse" }
  end
when "linuxbridge"
  directory "/etc/quantum/plugins/linuxbridge/" do
     mode 00775
     owner node[:quantum][:platform][:user]
     action :create
     recursive true
     not_if { node[:platform] == "suse" }
  end
end

unless node[:quantum][:use_gitrepo]
  link plugin_cfg_path do
    to "/etc/quantum/quantum.conf"
  end
  service node[:quantum][:platform][:service_name] do
    supports :status => true, :restart => true
    action :enable
    subscribes :restart, resources("template[/etc/quantum/api-paste.ini]"), :immediately
    subscribes :restart, resources("link[#{plugin_cfg_path}]"), :immediately
    subscribes :restart, resources("template[/etc/quantum/quantum.conf]")
  end
else
  template "/etc/quantum/plugins/openvswitch/ovs_quantum_plugin.ini" do
    source "ovs_quantum_plugin.ini.erb"
    owner node[:quantum][:platform][:user]
    group "root"
    mode "0640"
    variables(
        :ovs_sql_connection => node[:quantum][:db][:sql_connection]
    )
  end
  service quantum_service_name do
    supports :status => true, :restart => true
    action :enable
    subscribes :restart, resources("template[/etc/quantum/api-paste.ini]"), :immediately
    subscribes :restart, resources("template[/etc/quantum/plugins/openvswitch/ovs_quantum_plugin.ini]"), :immediately
    subscribes :restart, resources("template[/etc/quantum/quantum.conf]")
  end
end

service node[:quantum][:platform][:dhcp_agent_name] do
  supports :status => true, :restart => true
  action :enable
  subscribes :restart, resources("template[/etc/quantum/quantum.conf]")
  subscribes :restart, resources("template[/etc/quantum/dhcp_agent.ini]")
end

service node[:quantum][:platform][:l3_agent_name] do
  supports :status => true, :restart => true
  action :enable
  subscribes :restart, resources("template[/etc/quantum/quantum.conf]")
  subscribes :restart, resources("template[/etc/quantum/l3_agent.ini]")
end

include_recipe "quantum::post_install_conf"

node[:quantum][:monitor] = {} if node[:quantum][:monitor].nil?
node[:quantum][:monitor][:svcs] = [] if node[:quantum][:monitor][:svcs].nil?
node[:quantum][:monitor][:svcs] << ["quantum"] if node[:quantum][:monitor][:svcs].empty?
node.save

