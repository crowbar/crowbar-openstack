
# Copyright (c) 2011 Dell Inc.
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
default[:neutron][:config_file] = "/etc/neutron/neutron.conf.d/100-neutron.conf"
default[:neutron][:dhcp_agent_config_file] = "/etc/neutron/neutron-dhcp-agent.conf.d/100-dhcp_agent.conf"
default[:neutron][:lbaas_service_file] = "/etc/neutron/neutron-server.conf.d/100-neutron_service_lbaas.conf"
default[:neutron][:lbaas_agent_config_file] = "/etc/neutron/neutron-lbaasv2-agent.conf.d/100-lbaas_agent.conf"
default[:neutron][:lbaas_config_file] = "/etc/neutron/neutron.conf.d/110-neutron_lbaas.conf"
default[:neutron][:l3_agent_config_file] = "/etc/neutron/neutron-l3-agent.conf.d/100-agent.conf"
default[:neutron][:metadata_agent_config_file] = "/etc/neutron/neutron-metadata-agent.conf.d/100-metadata_agent.conf"
default[:neutron][:ml2_config_file] = "/etc/neutron/neutron.conf.d/110-ml2.conf"
default[:neutron][:nsx_config_file] = "/etc/neutron/neutron.conf.d/110-nsx.conf"
default[:neutron][:rpc_workers] = 1

default[:neutron][:db][:database] = "neutron"
default[:neutron][:db][:user] = "neutron"
default[:neutron][:db][:password] = "" # Set by Recipe
default[:neutron][:network][:fixed_router] = "127.0.0.1" # Set by Recipe
default[:neutron][:network][:private_networks] = [] # Set by Recipe

default[:neutron][:use_vpnaas] = false

default[:neutron][:gre][:tunnel_id_start] = 1
default[:neutron][:gre][:tunnel_id_stop] = 1000

default[:neutron][:vxlan][:vni_start] = 4096
default[:neutron][:vxlan][:vni_stop] = 99999
default[:neutron][:vxlan][:multicast_group] = "239.1.1.1"

default[:neutron][:api][:protocol] = "http"
default[:neutron][:api][:service_port] = "9696"
default[:neutron][:api][:service_host] = "0.0.0.0"

default[:neutron][:sql][:min_pool_size] = 30
default[:neutron][:sql][:max_pool_size] = 60
default[:neutron][:sql][:max_pool_overflow] = 10
default[:neutron][:sql][:pool_timeout] = 30

default[:neutron][:ssl][:certfile] = "/etc/neutron/ssl/certs/signing_cert.pem"
default[:neutron][:ssl][:keyfile] = "/etc/neutron/ssl/private/signing_key.pem"
default[:neutron][:ssl][:generate_certs] = false
default[:neutron][:ssl][:insecure] = false
default[:neutron][:ssl][:cert_required] = false
default[:neutron][:ssl][:ca_certs] = "/etc/neutron/ssl/certs/ca.pem"

default[:neutron][:apic][:system_id] = "soc"
default[:neutron][:apic][:hosts] = ""
default[:neutron][:apic][:username] = "admin"
default[:neutron][:apic][:password] = ""
default[:neutron][:apic][:optimized_metadata] = true
default[:neutron][:apic][:optimized_dhcp] = true
default[:neutron][:apic][:opflex] = [{
  pod: "",
  nodes: [],
  peer_ip: "",
  peer_port: "",
  encap: "vxlan",
  vxlan: {
    uplink_iface: "vlan.4093",
    uplink_vlan: 4093,
    encap_iface: "br-int_vxlan0",
    remote_ip: "",
    remote_port: 8472
  },
  vlan: {
    encap_iface: ""
  }
}]


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
    lbaasv2_agent_pkg: "openstack-neutron-lbaas-agent",
    lbaasv2_agent_name: "openstack-neutron-lbaasv2-agent",
    lbaas_haproxy_group: "haproxy",
    f5_agent_pkg: "",
    f5_agent_name: "f5-openstack-agent",
    infoblox_agent_name: "openstack-neutron-infoblox-ipam-agent",
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
    cisco_apic_pkgs: ["python-apicapi",
                      "python-neutron-ml2-driver-apic"],
    cisco_apic_gbp_pkgs: ["openstack-neutron-gbp",
                          "python-gbpclient"],
    cisco_opflex_pkgs: ["agent-ovs",
                        "lldpd",
                        "openstack-neutron-opflex-agent"],
    infoblox_pkgs: ["python-infoblox-client",
                    "openstack-neutron-infoblox",
                    "openstack-neutron-infoblox-ipam-agent"],
    vmware_vsphere_pkg: "openstack-neutron-vsphere",
    vmware_vsphere_dvs_agent_pkg: "openstack-neutron-vsphere-dvs-agent",
    user: "neutron",
    group: "neutron",
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
    lbaasv2_agent_pkg: "openstack-neutron-lbaas-agent",
    lbaasv2_agent_name: "neutron-lbaasv2-agent",
    lbaas_haproxy_group: "nogroup",
    f5_agent_pkg: "",
    f5_agent_name: "f5-openstack-agent",
    infoblox_agent_name: "",
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
    cisco_apic_pkgs: ["python-apicapi",
                      "python-neutron-ml2-driver-apic"],
    cisco_apic_gbp_pkgs: ["openstack-neutron-gbp",
                          "python-gbpclient"],
    cisco_opflex_pkgs: ["agent-ovs",
                        "lldpd",
                        "neutron-opflex-agent"],
    infoblox_pkgs: [],
    vmware_vsphere_pkg: "",
    vmware_vsphere_dvs_agent_pkg: "",
    user: "neutron",
    group: "neutron",
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
    lbaasv2_agent_pkg: "neutron-lbaas-agent",
    lbaasv2_agent_name: "neutron-lbaasv2-agent",
    lbaas_haproxy_group: "nogroup",
    f5_agent_pkg: "",
    f5_agent_name: "f5-oslbaasv2-agent",
    infoblox_agent_name: "",
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
    cisco_apic_pkgs: [""],
    cisco_apic_gbp_pkgs: [""],
    cisco_opflex_pkgs: [""],
    infoblox_pkgs: [],
    vmware_vsphere_pkg: "openstack-neutron-vsphere",
    vmware_vsphere_dvs_agent_pkg: "openstack-neutron-vsphere-dvs-agent",
    user: "neutron",
    group: "neutron",
  }
end

default[:neutron][:f5][:ha_type] = "standalone"
default[:neutron][:f5][:external_physical_mappings] = "default:1.1:True"
default[:neutron][:f5][:vtep_folder] = "Common"
default[:neutron][:f5][:vtep_selfip_name] = "vtep"
default[:neutron][:f5][:max_namespaces_per_tenant] = 1
default[:neutron][:f5][:route_domain_strictness] = false
default[:neutron][:f5][:icontrol_hostname] = ""
default[:neutron][:f5][:icontrol_username] = "admin"
default[:neutron][:f5][:icontrol_password] = "admin"
default[:neutron][:f5][:parent_ssl_profile] = "clientssl"

default[:neutron][:ha][:network][:enabled] = false
default[:neutron][:ha][:network][:l3_ra] = "systemd:#{node[:neutron][:platform][:l3_agent_name]}"
default[:neutron][:ha][:network][:lbaas_ra] = "systemd:#{node[:neutron][:platform][:lbaas_agent_name]}"
default[:neutron][:ha][:network][:lbaasv2_ra] = "systemd:#{node[:neutron][:platform][:lbaasv2_agent_name]}"
default[:neutron][:ha][:network][:f5_ra] = "systemd:#{node[:neutron][:platform][:f5_agent_name]}"
default[:neutron][:ha][:network][:dhcp_ra] = "systemd:#{node[:neutron][:platform][:dhcp_agent_name]}"
default[:neutron][:ha][:network][:metadata_ra] = "systemd:#{node[:neutron][:platform][:metadata_agent_name]}"
default[:neutron][:ha][:network][:metering_ra] = "systemd:#{node[:neutron][:platform][:metering_agent_name]}"
default[:neutron][:ha][:network][:openvswitch_ra] = "systemd:#{node[:neutron][:platform][:ovs_agent_name]}"
default[:neutron][:ha][:network][:cisco_ra] = "systemd:#{node[:neutron][:ha][:network][:openvswitch_ra]}"
default[:neutron][:ha][:network][:linuxbridge_ra] = "systemd:#{node[:neutron][:platform][:lb_agent_name]}"
default[:neutron][:ha][:network][:ha_tool_ra] = "ocf:openstack:neutron-ha-tool"
default[:neutron][:ha][:network][:op][:monitor][:interval] = "10s"
default[:neutron][:ha][:neutron_ha_tool][:op][:monitor][:interval] = "10s"
default[:neutron][:ha][:neutron_ha_tool][:op][:start][:timeout] = "1800s"
default[:neutron][:ha][:server][:enabled] = false
default[:neutron][:ha][:server][:server_ra] = "systemd:#{node[:neutron][:platform][:service_name]}"
default[:neutron][:ha][:server][:op][:monitor][:interval] = "10s"
default[:neutron][:ha][:infoblox][:enabled] = false
default[:neutron][:ha][:infoblox][:infoblox_ra] =
  "systemd:#{node[:neutron][:platform][:infoblox_agent_name]}"
default[:neutron][:ha][:infoblox][:op][:monitor][:interval] = "10s"
# Ports to bind to when haproxy is used for the real ports
default[:neutron][:ha][:ports][:server] = 5530

default[:neutron][:ha][:neutron_l3_ha_resource][:op][:monitor][:interval] = "10s"

default[:neutron][:ha][:neutron_l3_ha_service][:timeouts][:status][:terminate] = 300
default[:neutron][:ha][:neutron_l3_ha_service][:timeouts][:status][:kill] = 120
default[:neutron][:ha][:neutron_l3_ha_service][:timeouts][:router_migration][:terminate] = 1800
default[:neutron][:ha][:neutron_l3_ha_service][:timeouts][:router_migration][:kill] = 120
default[:neutron][:ha][:neutron_l3_ha_service][:hatool][:program] = "/usr/bin/neutron-ha-tool"
default[:neutron][:ha][:neutron_l3_ha_service][:hatool][:env] = {}
default[:neutron][:ha][:neutron_l3_ha_service][:seconds_to_sleep_between_checks] = 10
default[:neutron][:ha][:neutron_l3_ha_service][:max_errors_tolerated] = 10
default[:neutron][:ha][:neutron_l3_ha_service][:log_file] = "/var/log/neutron/neutron-l3-ha-service.log"
