#
# Copyright 2017 SUSE Linux GmBH
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

# Install all packages for contrail vrouter on compute node
# Need to manually install (with force downgrade) contrail-vrouter-common
# Command: zypper --no-gpg-checks --non-interactive in contrail-vrouter-common
node[:neutron][:platform][:contrail_compute_pkgs].each do |p|
  bash "install contrail packages" do
    user "root"
    code <<-EOF
      zypper --no-gpg-checks --non-interactive in --auto-agree-with-licenses --force #{p}
    EOF
  end
end

keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)

template "/etc/contrail/supervisord_vrouter.conf" do
  cookbook "neutron"
  source "supervisord_vrouter.conf.erb"
  mode "0640"
  owner "root"
  group node[:neutron][:platform][:group]
end

template "/etc/contrail/contrail-vrouter-agent.conf" do
  cookbook "neutron"
  source "contrail-vrouter-agent.conf.erb"
  mode "0640"
  owner "root"
  group node[:neutron][:platform][:group]
  variables(
    contrail_api_server_ip: neutron[:neutron][:contrail][:api_server_ip],
    gateway_api_server: neutron[:neutron][:contrail][:gateway_server_ip],
    metadata_proxy_secret: neutron[:nova][:neutron_metadata_proxy_shared_secret]
  )
end

template "/etc/contrail/supervisord_vrouter_files/contrail-vrouter-agent.ini" do
  cookbook "neutron"
  source "contrail-vrouter-agent.ini.erb"
  mode "0640"
  owner "root"
  group node[:neutron][:platform][:group]
end

template "/etc/contrail/contrail-vrouter-nodemgr.conf" do
  cookbook "neutron"
  source "contrail-vrouter-nodemgr.conf.erb"
  mode "0640"
  owner "root"
  group node[:neutron][:platform][:group]
  variables(
    contrail_api_server_ip: neutron[:neutron][:contrail][:api_server_ip]
  )
end

template "/etc/contrail/supervisord_vrouter_files/contrail-vrouter-nodemgr.ini" do
  cookbook "neutron"
  source "contrail-vrouter-nodemgr.ini.erb"
  mode "0640"
  owner "root"
  group node[:neutron][:platform][:group]
end

file "/etc/contrail/supervisord_vrouter_files/contrail-vrouter.rules" do
  content '{ "Rules": [
               ]
           }'
  mode "0640"
  owner "root"
  group node[:neutron][:platform][:group]
end

file "/etc/contrail/agent_param" do
  content "LOG=/var/log/contrail.log
           CONFIG=/etc/contrail/agent.conf
           prog=/usr/bin/contrail-vrouter-agent
           kmod=vrouter
           pname=contrail-vrouter-agent
           LIBDIR=/usr/lib64
           VHOST_CFG=/etc/sysconfig/network-scripts/ifcfg-vhost0
           dev=eth0
           vgw_subnet_ip=
           vgw_intf=
           qos_enabled=false
           LOGFILE=--log-file=/var/log/contrail/vrouter.log"
  mode "0640"
  owner "root"
  group node[:neutron][:platform][:group]
end



