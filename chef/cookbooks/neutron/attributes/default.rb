
# Copyright (c) 2011 Dell Inc.
# Copyright (c) 2016 SUSE Linux GmbH
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

override[:neutron][:user]="neutron"
override[:neutron][:group]="neutron"

default[:neutron][:debug] = false
default[:neutron][:verbose] = false
default[:neutron][:max_header_line] = 16384
default[:neutron][:dhcp_domain] = "openstack.local"
default[:neutron][:networking_plugin] = "ml2"
default[:neutron][:additional_external_networks] = []

default[:neutron][:db][:database] = "neutron"
default[:neutron][:db][:user] = "neutron"
default[:neutron][:db][:password] = "" # Set by Recipe
default[:neutron][:network][:fixed_router] = "127.0.0.1" # Set by Recipe
default[:neutron][:network][:private_networks] = [] # Set by Recipe

default[:neutron][:gre][:tunnel_id_start] = 1
default[:neutron][:gre][:tunnel_id_stop] = 1000

default[:neutron][:vxlan][:vni_start] = 4096
default[:neutron][:vxlan][:vni_stop] = 99999
default[:neutron][:vxlan][:multicast_group] = "239.1.1.1"

default[:neutron][:api][:protocol] = "http"
default[:neutron][:api][:service_port] = "9696"
default[:neutron][:api][:service_host] = "0.0.0.0"

default[:neutron][:sql][:min_pool_size] = 30
default[:neutron][:sql][:max_pool_overflow] = 10
default[:neutron][:sql][:pool_timeout] = 30

default[:neutron][:ssl][:certfile] = "/etc/neutron/ssl/certs/signing_cert.pem"
default[:neutron][:ssl][:keyfile] = "/etc/neutron/ssl/private/signing_key.pem"
default[:neutron][:ssl][:generate_certs] = false
default[:neutron][:ssl][:insecure] = false
default[:neutron][:ssl][:cert_required] = false
default[:neutron][:ssl][:ca_certs] = "/etc/neutron/ssl/certs/ca.pem"

case node[:platform_family]
when "suse"
  default[:neutron][:platform] = {
    pkgs: ["openstack-neutron-server"],
    pkgs_fwaas: ["openstack-neutron-fwaas"],
    pkgs_lbaas: ["openstack-neutron-lbaas"],
    service_name: "openstack-neutron",
    ovs_agent_pkg: "openstack-neutron-openvswitch-agent",
    ovs_agent_name: "openstack-neutron-openvswitch-agent",
    lb_agent_pkg: "openstack-neutron-linuxbridge-agent",
    lb_agent_name: "openstack-neutron-linuxbridge-agent",
    zvm_agent_pkg: "openstack-neutron-zvm-agent",
    zvm_agent_name: "openstack-neutron-zvm-agent",
    lbaas_agent_pkg: "openstack-neutron-lbaas-agent",
    lbaas_agent_name: "openstack-neutron-lbaas-agent",
    lbaas_haproxy_group: "haproxy",
    vpnaas_agent_pkg: "openstack-neutron-vpn-agent",
    vpnaas_agent_name: "openstack-neutron-vpn-agent",
    vpnaas_agent_device_driver_pkgs: ["strongswan"],
    metadata_agent_name: "openstack-neutron-metadata-agent",
    metadata_agent_pkg: "openstack-neutron-metadata-agent",
    metering_agent_pkg: "openstack-neutron-metering-agent",
    metering_agent_name: "openstack-neutron-metering-agent",
    dhcp_agent_name: "openstack-neutron-dhcp-agent",
    dhcp_agent_pkg: "openstack-neutron-dhcp-agent",
    l3_agent_name: "openstack-neutron-l3-agent",
    l3_agent_pkg: "openstack-neutron-l3-agent",
    ha_tool_pkg: "openstack-neutron-ha-tool",
    hyperv_pkg: "python-networking-hyperv",
    nsx_pkgs: ["openvswitch-pki",
                   "ruby2.1-rubygem-faraday"],
    cisco_pkgs: ["python-networking-cisco"],
    user: "neutron",
    group: "neutron",
    neutron_rootwrap_sudo_template: "/etc/sudoers.d/openstack-neutron"
  }
when "rhel"
  default[:neutron][:platform] = {
    pkgs: ["openstack-neutron"],
    pkgs_fwaas: ["openstack-neutron-fwaas"],
    pkgs_lbaas: ["openstack-neutron-lbaas"],
    service_name: "neutron-server",
    ovs_agent_pkg: "openstack-neutron-openvswitch",
    ovs_agent_name: "neutron-openvswitch-agent",
    lb_agent_pkg: "openstack-neutron-linuxbridge",
    lb_agent_name: "neutron-linuxbridge-agent",
    zvm_agent_pkg: "openstack-neutron-zvm-agent",
    zvm_agent_name: "openstack-neutron-zvm-agent",
    lbaas_agent_pkg: "openstack-neutron-lbaas-agent",
    lbaas_agent_name: "neutron-lbaas-agent",
    lbaas_haproxy_group: "nogroup",
    vpnaas_agent_pkg: "openstack-neutron-vpn-agent",
    vpnaas_agent_name: "openstack-neutron-vpn-agent",
    vpnaas_agent_device_driver_pkgs: ["strongswan"],
    metadata_agent_name: "neutron-metadata-agent",
    metadata_agent_pkg: "openstack-neutron",
    metering_agent_pkg: "openstack-neutron-metering-agent",
    metering_agent_name: "neutron-metering-agent",
    dhcp_agent_name: "neutron-dhcp-agent",
    dhcp_agent_pkg: "openstack-neutron",
    l3_agent_name: "neutron-l3-agent",
    l3_agent_pkg: "openstack-neutron",
    ha_tool_pkg: "",
    hyperv_pkg: "",
    nsx_pkgs: [""],
    cisco_pkgs: ["python-networking-cisco"],
    user: "neutron",
    group: "neutron",
    neutron_rootwrap_sudo_template: "/etc/sudoers.d/openstack-neutron"
  }
else
  default[:neutron][:platform] = {
    pkgs: ["neutron-server",
               "neutron-plugin-openvswitch"],
    pkgs_fwaas: ["neutron-fwaas"],
    pkgs_lbaas: ["neutron-lbaas"],
    service_name: "neutron-server",
    ovs_agent_pkg: "neutron-plugin-openvswitch-agent",
    ovs_agent_name: "neutron-plugin-openvswitch-agent",
    lb_agent_pkg: "neutron-plugin-linuxbridge-agent",
    lb_agent_name: "neutron-plugin-linuxbridge-agent",
    zvm_agent_pkg: "neutron-zvm-agent",
    zvm_agent_name: "neutron-zvm-agent",
    lbaas_agent_pkg: "neutron-lbaas-agent",
    lbaas_agent_name: "neutron-lbaas-agent",
    lbaas_haproxy_group: "nogroup",
    vpnaas_agent_pkg: "openstack-neutron-vpn-agent",
    vpnaas_agent_name: "openstack-neutron-vpn-agent",
    vpnaas_agent_device_driver_pkgs: ["strongswan"],
    metadata_agent_name: "neutron-metadata-agent",
    metadata_agent_pkg: "neutron-metadata-agent",
    metering_agent_pkg: "neutron-plugin-metering-agent",
    metering_agent_name: "neutron-plugin-metering-agent",
    dhcp_agent_name: "neutron-dhcp-agent",
    dhcp_agent_pkg: "neutron-dhcp-agent",
    l3_agent_name: "neutron-l3-agent",
    l3_agent_pkg: "neutron-l3-agent",
    ha_tool_pkg: "",
    hyperv_pkg: "python-networking-hyperv",
    nsx_pkgs: [""],
    cisco_pkgs: [""],
    user: "neutron",
    group: "neutron",
    neutron_rootwrap_sudo_template: "/etc/sudoers.d/neutron-rootwrap"
  }
end

default[:neutron][:ha][:network][:enabled] = false
default[:neutron][:ha][:network][:l3_ra] = "lsb:#{node[:neutron][:platform][:l3_agent_name]}"
default[:neutron][:ha][:network][:lbaas_ra] = "lsb:#{node[:neutron][:platform][:lbaas_agent_name]}"
default[:neutron][:ha][:network][:vpnaas_ra] = "lsb:#{node[:neutron][:platform][:vpnaas_agent_name]}"
default[:neutron][:ha][:network][:dhcp_ra] = "lsb:#{node[:neutron][:platform][:dhcp_agent_name]}"
default[:neutron][:ha][:network][:metadata_ra] = "lsb:#{node[:neutron][:platform][:metadata_agent_name]}"
default[:neutron][:ha][:network][:metering_ra] = "lsb:#{node[:neutron][:platform][:metering_agent_name]}"
default[:neutron][:ha][:network][:openvswitch_ra] = "lsb:#{node[:neutron][:platform][:ovs_agent_name]}"
default[:neutron][:ha][:network][:cisco_ra] = "lsb:#{node[:neutron][:ha][:network][:openvswitch_ra]}"
default[:neutron][:ha][:network][:linuxbridge_ra] = "lsb:#{node[:neutron][:platform][:lb_agent_name]}"
default[:neutron][:ha][:network][:ha_tool_ra] = "ocf:openstack:neutron-ha-tool"
default[:neutron][:ha][:network][:op][:monitor][:interval] = "10s"
default[:neutron][:ha][:neutron_ha_tool][:op][:monitor][:interval] = "10s"
default[:neutron][:ha][:neutron_ha_tool][:op][:start][:timeout] = "120s"
default[:neutron][:ha][:server][:enabled] = false
default[:neutron][:ha][:server][:server_ra] = "lsb:#{node[:neutron][:platform][:service_name]}"
default[:neutron][:ha][:server][:op][:monitor][:interval] = "10s"
# Ports to bind to when haproxy is used for the real ports
default[:neutron][:ha][:ports][:server] = 5530
