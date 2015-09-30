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

if node[:platform_family] == "debian"
  # If we expect to install the openvswitch module via DKMS, but the module
  # does not exist, rmmod the openvswitch module before continuing.
  if node[:network][:ovs_pkgs].any? { |e| e == "openvswitch-datapath-dkms" } &&
      !File.exists?("/lib/modules/#{`uname -r`.strip}/updates/dkms/openvswitch.ko") &&
      File.directory?("/sys/module/openvswitch")
    if IO.read("/sys/module/openvswitch/refcnt").strip != "0"
      Chef::Log.error("Kernel openvswitch module already loaded and in use! Please reboot me!")
    else
      bash "Unload non-DKMS openvswitch module" do
        code "rmmod openvswitch"
      end
    end
  end
end

node[:network][:ovs_pkgs].each { |p| package p }

bash "Load openvswitch module" do
  code "modeprobe #{node[:network][:ovs_module]}"
  not_if { ::File.directory?("/sys/module/#{node[:network][:ovs_module]}") }
end

service node[:network][:ovs_service] do
  supports status: true, restart: true
  action [:start, :enable]
end

node[:neutron][:platform][:nsx_pkgs].each { |p| package p }

nsx_controller = neutron[:neutron][:vmware][:controllers].split(",")[0]

execute "set_initial_controller" do
  command "ovs-vsctl set-manager ssl:#{nsx_controller}"
  notifies :run, "execute[ovs_pki_init]", :immediately
  not_if "ovs-vsctl show | grep -q Manager"
end

# Initialize the PKI
execute "ovs_pki_init" do
  command "ovs-pki init --force"
  notifies :run, "execute[ovs_pki_req_sign]", :immediately
  action :nothing
end

# Combine the above two steps, producing all three files
execute "ovs_pki_req_sign" do
  command "cd /etc/openvswitch; ovs-pki req+sign ovsclient controller --force"
  notifies :run, "execute[ovs_bootstrap_ssl]", :immediately
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
end

# Make sure br-int is always up.
ruby_block "Bring up the internal bridge" do
  block do
    ::Nic.new("br-int").up
  end
end

execute "set_external_id" do
  command "ovs-vsctl br-set-external-id br-int bridge-id br-int"
end

execute "set_bridge_config" do
  command "ovs-vsctl set Bridge br-int other_config:disable-in-band=true -- set Bridge br-int fail_mode=secure"
end

# Create br1, it will be used for vlan backends
execute "create_int_br1" do
  command "ovs-vsctl add-br br1"
  not_if "ovs-vsctl list-br | grep -q br1"
end

# Make sure br1 is always up.
ruby_block "Bring up the internal bridge br1" do
  block do
    ::Nic.new("br1").up
  end
end

execute "set_external_id_br1" do
  command "ovs-vsctl br-set-external-id br1 bridge-id br1"
end

execute "set_bridge_config_br1" do
  command "ovs-vsctl set Bridge br1 fail_mode=standalone"
end

bound_if = node[:crowbar_wall][:network][:nets][:os_sdn].first
admin_if = node[:crowbar_wall][:network][:nets][:admin].first
# We have to be sure that admin interface will not be assigned to VLAN
# bridge in NSX mode, because we will lose connection to this node.
unless bound_if == admin_if
  execute "add_bound_if_to_br1" do
    command "ovs-vsctl add-port br1 #{bound_if}"
    not_if "ovs-vsctl list-ports br1 | grep -q #{bound_if}"
  end
end

# After installation of ruby-faraday, we have a new path for the new gem, so we
# need to reset the paths if we can't load ruby-faraday
begin
  require "faraday"
rescue LoadError
  Gem.clear_paths
end

nsx_data = {}
unless neutron[:neutron][:vmware][:controllers].empty?
  nsx_data["host"] = neutron[:neutron][:vmware][:controllers].split(",").first
else
  Chef::Log.error "No NSX controller has been found."
end
nsx_data["port"] = neutron[:neutron][:vmware][:port]
nsx_data["username"] = neutron[:neutron][:vmware][:user]
nsx_data["password"] = neutron[:neutron][:vmware][:password]

nsx_transport_node node.name.split(".").first do
  nsx_controller nsx_data
  client_pem_file "/etc/openvswitch/ovsclient-cert.pem"
  integration_bridge_id "br-int"
  tunnel_probe_random_vlan true
  transport_connectors([
    {
      "transport_zone_uuid" => neutron[:neutron][:vmware][:tz_uuid],
      "ip_address" => node[:crowbar][:network][:os_sdn][:address],
      "type" => "STTConnector"
    },
    {
      "transport_zone_uuid" => neutron[:neutron][:vmware][:tz_uuid],
      "bridge_id" => "br1",
      "type" => "BridgeConnector"
    }
  ])
end
