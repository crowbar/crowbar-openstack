
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

unless node[:platform] == "suse"
  override[:neutron][:user]="neutron"
  override[:neutron][:group]="neutron"
else
  override[:neutron][:user]="openstack-neutron"
  override[:neutron][:group]="openstack-neutron"
end

default[:neutron][:debug] = false
default[:neutron][:verbose] = false
default[:neutron][:dhcp_domain] = "openstack.local"
default[:neutron][:networking_mode] = "local"
default[:neutron][:networking_plugin] = "openvswitch"
default[:neutron][:cisco_support] = false

default[:neutron][:db][:database] = "neutron"
default[:neutron][:db][:user] = "neutron"
default[:neutron][:db][:password] = "" # Set by Recipe
default[:neutron][:network][:fixed_router] = "127.0.0.1" # Set by Recipe
default[:neutron][:network][:private_networks] = [] # Set by Recipe
# Default range for GRE tunnels
default[:neutron][:network][:gre_start] = 1
default[:neutron][:network][:gre_stop] = 1000


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

default[:neutron][:neutron_server] = false

case node["platform"]
when "suse"
  default[:neutron][:platform] = {
    :pkgs => [ "openstack-neutron-server" ],
    :service_name => "openstack-neutron",
    :ovs_agent_pkg => "openstack-neutron-openvswitch-agent",
    :ovs_agent_name => "openstack-neutron-openvswitch-agent",
    :lb_agent_pkg => "openstack-neutron-linuxbridge-agent",
    :lb_agent_name => "openstack-neutron-linuxbridge-agent",
    :nvp_agent_pkg => "openstack-neutron-vmware-agent",
    :nvp_agent_name => "openstack-neutron-vmware-agent",
    :metadata_agent_name => "openstack-neutron-metadata-agent",
    :metadata_agent_pkg => "openstack-neutron-metadata-agent",
    :metering_agent_pkg => "openstack-neutron-metering-agent",
    :metering_agent_name => "openstack-neutron-metering-agent",
    :dhcp_agent_name => "openstack-neutron-dhcp-agent",
    :dhcp_agent_pkg => "openstack-neutron-dhcp-agent",
    :l3_agent_name => "openstack-neutron-l3-agent",
    :l3_agent_pkg => "openstack-neutron-l3-agent",
    :ha_tool_pkg => "openstack-neutron-ha-tool",
    :ovs_pkgs => [ "openvswitch",
                   "openvswitch-switch",
                   "openvswitch-kmp-default" ],
    :cisco_pkgs => [ "openstack-neutron-plugin-cisco" ],
    :user => "openstack-neutron",
    :ovs_modprobe => "modprobe openvswitch",
    :neutron_rootwrap_sudo_template => "/etc/sudoers.d/openstack-neutron"
  }
when "centos", "redhat"
  default[:neutron][:platform] = {
    :pkgs => [ "openstack-neutron" ],
    :service_name => "neutron-server",
    :ovs_agent_pkg => "openstack-neutron-openvswitch",
    :ovs_agent_name => "neutron-openvswitch-agent",
    :lb_agent_pkg => "openstack-neutron-linuxbridge",
    :lb_agent_name => "neutron-linuxbridge-agent",
    :nvp_agent_pkg => "openstack-neutron-nicira",
    :nvp_agent_name => "neutron-nicira-agent",
    :metadata_agent_name => "neutron-metadata-agent",
    :metadata_agent_pkg => "openstack-neutron",
    :metering_agent_pkg => "openstack-neutron-metering-agent",
    :metering_agent_name => "neutron-metering-agent",
    :dhcp_agent_name => "neutron-dhcp-agent",
    :dhcp_agent_pkg => "openstack-neutron",
    :l3_agent_name => "neutron-l3-agent",
    :l3_agent_pkg => "openstack-neutron",
    :ha_tool_pkg => "",
    :ovs_pkgs => [ "openvswitch",
                   "openstack-neutron-openvswitch" ],
    :user => "neutron",
    :ovs_modprobe => "modprobe openvswitch",
    :neutron_rootwrap_sudo_template => "/etc/sudoers.d/openstack-neutron"
  }
else
  default[:neutron][:platform] = {
    :pkgs => [ "neutron-server",
               "neutron-plugin-openvswitch" ],
    :service_name => "neutron-server",
    :ovs_agent_pkg => "neutron-plugin-openvswitch-agent",
    :ovs_agent_name => "neutron-plugin-openvswitch-agent",
    :lb_agent_pkg => "neutron-plugin-linuxbridge-agent",
    :lb_agent_name => "neutron-plugin-linuxbridge-agent",
    :nvp_agent_pkg => "neutron-plugin-nicira-agent",
    :nvp_agent_name => "neutron-plugin-nicira-agent",
    :metadata_agent_name => "neutron-metadata-agent",
    :metadata_agent_pkg => "neutron-metadata-agent",
    :metering_agent_pkg => "neutron-plugin-metering-agent",
    :metering_agent_name => "neutron-metering-agent",
    :dhcp_agent_name => "neutron-dhcp-agent",
    :dhcp_agent_pkg => "neutron-dhcp-agent",
    :l3_agent_name => "neutron-l3-agent",
    :l3_agent_pkg => "neutron-l3-agent",
    :ha_tool_pkg => "",
    :ovs_pkgs => [ "linux-headers-#{`uname -r`.strip}",
                   "openvswitch-datapath-dkms",
                   "openvswitch-switch" ],
    :cisco_pkgs => [ "" ],
    :user => "neutron",
    :ovs_modprobe => "modprobe openvswitch",
    :neutron_rootwrap_sudo_template => "/etc/sudoers.d/neutron-rootwrap"
  }
end

default[:neutron][:ha][:l3][:enabled] = false
default[:neutron][:ha][:l3][:l3_ra] = "lsb:openstack-neutron-l3-agent"
default[:neutron][:ha][:l3][:dhcp_ra] = "lsb:openstack-neutron-dhcp-agent"
default[:neutron][:ha][:l3][:metadata_ra] = "lsb:openstack-neutron-metadata-agent"
default[:neutron][:ha][:l3][:metering_ra] = "lsb:openstack-neutron-metering-agent"
default[:neutron][:ha][:l3][:ha_tool_ra] = "ocf:openstack:neutron-ha-tool"
default[:neutron][:ha][:l3][:op][:monitor][:interval] = "10s"
default[:neutron][:ha][:server][:enabled] = false
default[:neutron][:ha][:server][:server_ra] = "lsb:#{default[:neutron][:platform][:service_name]}"
default[:neutron][:ha][:server][:op][:monitor][:interval] = "10s"
# Ports to bind to when haproxy is used for the real ports
default[:neutron][:ha][:ports][:server] = 5530
