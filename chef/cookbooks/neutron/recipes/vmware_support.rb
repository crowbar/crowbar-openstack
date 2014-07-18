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

neutron = nil
if node.attribute?(:cookbook) and node[:cookbook] == "nova"
  neutrons = search(:node, "roles:neutron-server AND roles:neutron-config-#{node[:nova][:neutron_instance]}")
  neutron = neutrons.first || raise("Neutron instance '#{node[:nova][:neutron_instance]}' for nova not found")
else
  neutron = node
end

node[:neutron][:platform][:nsx_pkgs].each { |p| package p }

nsx_controller = neutron[:neutron][:vmware][:controllers].split(",")[0]

execute "set_initial_controller" do
  command "ovs-vsctl set-manager ssl:#{nsx_controller}"
  not_if "ovs-vsctl show | grep -q Manager"
end

# Initialize the PKI
execute "ovs_pki_init" do
  command "ovs-pki init"
  notifies :run, "execute[ovs_pki_req_sign]"
  not_if { File.exists?("/var/lib/openvswitch/pki") }
end

# Combine the above two steps, producing all three files
execute "ovs_pki_req_sign" do
  command "cd /etc/openvswitch; ovs-pki req+sign ovsclient controller"
  notifies :run, "execute[ovs_bootstrap_ssl]"
  action :nothing
end

# Bootstrap SSL certificates
execute "ovs_bootstrap_ssl" do
  command "ovs-vsctl -- --bootstrap set-ssl /etc/openvswitch/ovsclient-privkey.pem /etc/openvswitch/ovsclient-cert.pem /etc/openvswitch/controller-ca-cert.pem"
  action :nothing
end

# We always need br-int, it will be used for stt
execute "create_int_br" do
  command "ovs-vsctl add-br br-int"
  not_if "ovs-vsctl list-br | grep -q br-int"
  notifies :run, "execute[set_external_id]"
end

# Make sure br-int is always up.
ruby_block "Bring up the internal bridge" do
  block do
    ::Nic.new('br-int').up
  end
end

execute "set_external_id" do
  command "ovs-vsctl br-set-external-id br-int bridge-id br-int"
  notifies :run, "execute[set_bridge_config]"
  action :nothing
end

execute "set_bridge_config" do
  command "ovs-vsctl set Bridge br-int other_config:disable-in-band=true -- set Bridge br-int fail_mode=secure"
  action :nothing
end

# Create br1, it will be used for vlan backends
execute "create_int_br1" do
  command "ovs-vsctl add-br br1"
  not_if "ovs-vsctl list-br | grep -q br1"
  notifies :run, "execute[set_external_id_br1]"
end

# Make sure br1 is always up.
ruby_block "Bring up the internal bridge br1" do
  block do
    ::Nic.new('br1').up
  end
end

execute "set_external_id_br1" do
  command "ovs-vsctl br-set-external-id br1 bridge-id br1"
  notifies :run, "execute[set_bridge_config_br1]"
  action :nothing
end

execute "set_bridge_config_br1" do
  command "ovs-vsctl set Bridge br1 fail_mode=standalone"
  notifies :run, "execute[add_bound_if_to_br1]"
  action :nothing
end

bound_if = node[:crowbar_wall][:network][:nets][:os_sdn].first
execute "add_bound_if_to_br1" do
  command "ovs-vsctl add-port br1 #{bound_if}"
  action :nothing
end
