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
    quantum_agent = node[:quantum][:platform][:ovs_agent_name]
  when "linuxbridge"
    plugin_cfg_path = "/etc/quantum/plugins/linuxbridge/linuxbridge_conf.ini"
    quantum_agent = node[:quantum][:platform][:lb_agent_name]
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
  quantum_agent = "quantum-openvswitch-agent"
  plugin_cfg_path = "/etc/quantum/plugins/openvswitch/ovs_quantum_plugin.ini"
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

keystone_host = keystone[:fqdn]
keystone_protocol = keystone["keystone"]["api"]["protocol"]
keystone_service_port = keystone["keystone"]["api"]["service_port"]
keystone_admin_port = keystone["keystone"]["api"]["admin_port"]
keystone_service_tenant = keystone["keystone"]["service"]["tenant"]
keystone_service_user = node["quantum"]["service_user"]
keystone_service_password = node["quantum"]["service_password"]
keystone_service_url = "#{keystone_protocol}://#{keystone_host}:#{keystone_admin_port}/v2.0"
Chef::Log.info("Keystone server found at #{keystone_host}")

template "/etc/quantum/api-paste.ini" do
  source "api-paste.ini.erb"
  owner node[:quantum][:platform][:user]
  group "root"
  mode "0640"
  variables(
    :keystone_protocol => keystone_protocol,
    :keystone_host => keystone_host,
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
    :dhcp_domain => node[:quantum][:dhcp_domain],
    :enable_isolated_metadata => "True",
    :enable_metadata_network => "False",
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
metadata_host = nova[:fqdn]
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
    :nova_metadata_host => metadata_host,
    :nova_metadata_port => metadata_port,
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
  # no need to create link for plugin_cfg_path here; already handled in
  # common_install recipe
  service node[:quantum][:platform][:service_name] do
    supports :status => true, :restart => true
    action :enable
    # no subscribes for :restart; this is handled by the
    # "mark quantum-server as restart for post-install" ruby_block
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
    subscribes :restart, resources("template[/etc/quantum/api-paste.ini]")
    subscribes :restart, resources("template[/etc/quantum/plugins/openvswitch/ovs_quantum_plugin.ini]")
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

# This is some bad hack: we need to restart the server and the agent before
# post_install_conf if there was a configuration change. We cannot use
# :immediately to directly restart the services earlier, because they would be
# started before all configuration files get written.
services_to_restart = []

ruby_block "mark quantum-server as restart for post-install" do
  block do
    _service_name = node[:quantum][:platform][:service_name]
    _service_name = quantum_service_name if node[:quantum][:use_gitrepo]
    unless services_to_restart.include?(_service_name)
      services_to_restart << _service_name
    end
  end
  action :nothing
  subscribes :create, resources("template[/etc/quantum/api-paste.ini]"), :immediately
  subscribes :create, resources("link[#{plugin_cfg_path}]"), :immediately
  subscribes :create, resources("template[/etc/quantum/quantum.conf]"), :immediately
end

ruby_block "mark quantum-agent as restart for post-install" do
  block do
    unless services_to_restart.include?(quantum_agent)
      services_to_restart << quantum_agent
    end
  end
  action :nothing
  subscribes :create, resources("link[#{plugin_cfg_path}]"), :immediately
  subscribes :create, resources("template[/etc/quantum/quantum.conf]"), :immediately
end

ruby_block "restart services for post-install" do
  block do
    services_to_restart.each do |service|
      Chef::Log.info("Restarting #{service}")
      %x{/sbin/service #{service} restart}
    end
  end
end

include_recipe "quantum::post_install_conf"

node[:quantum][:monitor] = {} if node[:quantum][:monitor].nil?
node[:quantum][:monitor][:svcs] = [] if node[:quantum][:monitor][:svcs].nil?
node[:quantum][:monitor][:svcs] << ["quantum"] if node[:quantum][:monitor][:svcs].empty?
node.save

