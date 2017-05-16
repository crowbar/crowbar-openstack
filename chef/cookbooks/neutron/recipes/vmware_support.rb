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

networking_plugin = node[:neutron][:networking_plugin]
neutron = nil
if node.attribute?(:cookbook) and node[:cookbook] == "nova"
  neutrons = node_search_with_cache("roles:neutron-server", node[:nova][:neutron_instance])
  neutron = neutrons.first || raise("Neutron instance '#{node[:nova][:neutron_instance]}' for nova not found")
else
  neutron = node
end

if node[:platform_family] == "debian"
  # If we expect to install the openvswitch module via DKMS, but the module
  # does not exist, rmmod the openvswitch module before continuing.
  if node[:network][:ovs_pkgs].any? { |e| e == "openvswitch-datapath-dkms" } &&
      !File.exist?("/lib/modules/#{`uname -r`.strip}/updates/dkms/openvswitch.ko") &&
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
  code "modprobe #{node[:network][:ovs_module]}"
  not_if { ::File.directory?("/sys/module/#{node[:network][:ovs_module]}") }
end

service node[:network][:ovs_service] do
  supports status: true, restart: true
  action [:start, :enable]
end

node[:neutron][:platform][:nsx_pkgs].each { |p| package p }

if networking_plugin == "vmware_nsx"
  nsx_controller = neutron[:neutron][:vmware_nsx][:controllers].split(",")[0]

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
    command "ovs-vsctl -- --bootstrap set-ssl "\
            "/etc/openvswitch/ovsclient-privkey.pem "\
            "/etc/openvswitch/ovsclient-cert.pem "\
            "/etc/openvswitch/controller-ca-cert.pem"
    action :nothing
  end
end

# We always need br-int, it will be used for stt in case of NSX,
# or for DVS in case of DVS
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

if networking_plugin == "vmware_nsx"

  execute "set_bridge_config" do
    command "ovs-vsctl set Bridge br-int other_config:disable-in-band=true "\
            "-- set Bridge br-int fail_mode=secure"
    not_if { networking_plugin == "vmware_dvs" }
  end

  # Create br1, it will be used for vlan backends
  execute "create_int_br1" do
    command "ovs-vsctl add-br br1"
    not_if "ovs-vsctl list-br | grep -q br1"
    not_if { networking_plugin == "vmware_dvs" }
  end

  # Make sure br1 is always up.
  ruby_block "Bring up the internal bridge br1" do
    block do
      ::Nic.new("br1").up
    end
  end

  execute "set_external_id_br1" do
    command "ovs-vsctl br-set-external-id br1 bridge-id br1"
    not_if { networking_plugin == "vmware_dvs" }
  end

  execute "set_bridge_config_br1" do
    command "ovs-vsctl set Bridge br1 fail_mode=standalone"
    not_if { networking_plugin == "vmware_dvs" }
  end
end

configured_nets = node[:crowbar_wall][:network][:nets]
bound_if = configured_nets[:nova_floating].first
unless configured_nets[:os_sdn].nil?
  bound_if = node[:crowbar_wall][:network][:nets][:os_sdn].first
end
admin_if = node[:crowbar_wall][:network][:nets][:admin].first
# We have to be sure that admin interface will not be assigned to VLAN
# bridge in NSX mode, because we will lose connection to this node.
unless bound_if == admin_if
  vlan_bridge = networking_plugin == "vmware_dvs" ? "br-int" : "br1"

  execute "add_bound_if_to_vlan_bridge" do
    command "ovs-vsctl add-port #{vlan_bridge} #{bound_if}"
    not_if "ovs-vsctl list-ports #{vlan_bridge} | grep -q #{bound_if}"
  end
end

if networking_plugin == "vmware_dvs"
  return # skip anything else in this recipe if DVS
end

# After installation of ruby-faraday, we have a new path for the new gem, so we
# need to reset the paths if we can't load ruby-faraday
begin
  require "faraday"
rescue LoadError
  Gem.clear_paths
end

nsx_data = {}
if neutron[:neutron][:vmware_nsx][:controllers].empty?
  Chef::Log.error "No NSX controller has been found."
else
  nsx_data["host"] = neutron[:neutron][:vmware_nsx][:controllers].split(",").first
end
nsx_data["port"] = neutron[:neutron][:vmware_nsx][:port]
nsx_data["username"] = neutron[:neutron][:vmware_nsx][:user]
nsx_data["password"] = neutron[:neutron][:vmware_nsx][:password]

os_sdn_net = Barclamp::Inventory.get_network_by_type(node, "os_sdn")

nsx_transport_node node.name.split(".").first do
  nsx_controller nsx_data
  client_pem_file "/etc/openvswitch/ovsclient-cert.pem"
  integration_bridge_id "br-int"
  tunnel_probe_random_vlan true
  transport_connectors([
    {
      "transport_zone_uuid" => neutron[:neutron][:vmware_nsx][:tz_uuid],
      "ip_address" => os_sdn_net.address,
      "type" => "STTConnector"
    },
    {
      "transport_zone_uuid" => neutron[:neutron][:vmware_nsx][:tz_uuid],
      "bridge_id" => "br1",
      "type" => "BridgeConnector"
    }
  ])
end
