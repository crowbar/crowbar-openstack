
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
default[:neutron][:db][:ovs_database] = "ovs"
default[:neutron][:db][:ovs_user] = "ovs"
default[:neutron][:db][:ovs_password] = "" # Set by Recipe
default[:neutron][:db][:cisco_database] = "cisco_ovs"
default[:neutron][:db][:cisco_user] = "cisco_ovs"
default[:neutron][:db][:cisco_password] = "" # Set by Recipe
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
    :pkgs => [ "openstack-neutron-server",
               "openstack-neutron-l3-agent",
               "openstack-neutron-dhcp-agent",
               "openstack-neutron-metadata-agent" ],
    :service_name => "openstack-neutron",
    :ovs_agent_pkg => "openstack-neutron-openvswitch-agent",
    :ovs_agent_name => "openstack-neutron-openvswitch-agent",
    :lb_agent_pkg => "openstack-neutron-linuxbridge-agent",
    :lb_agent_name => "openstack-neutron-linuxbridge-agent",
    :metadata_agent_name => "openstack-neutron-metadata-agent",
    :dhcp_agent_name => "openstack-neutron-dhcp-agent",
    :l3_agent_name => "openstack-neutron-l3-agent",
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
    :lb_agent_name => "openstack-neutron-linuxbridge-agent",
    :metadata_agent_name => "neutron-metadata-agent",
    :dhcp_agent_name => "neutron-dhcp-agent",
    :l3_agent_name => "neutron-l3-agent",
    :ovs_pkgs => [ "openvswitch",
                   "openstack-neutron-openvswitch" ],
    :user => "neutron",
    :ovs_modprobe => "modprobe openvswitch",
    :neutron_rootwrap_sudo_template => "/etc/sudoers.d/openstack-neutron"
  }
else
  default[:neutron][:platform] = {
    :pkgs => [ "neutron-server",
               "neutron-l3-agent",
               "neutron-dhcp-agent",
               "neutron-plugin-openvswitch",
               "neutron-metadata-agent" ],
    :service_name => "neutron-server",
    :ovs_agent_pkg => "neutron-plugin-openvswitch-agent",
    :ovs_agent_name => "neutron-plugin-openvswitch-agent",
    :lb_agent_pkg => "neutron-plugin-linuxbridge-agent",
    :lb_agent_name => "neutron-plugin-linuxbridge-agent",
    :metadata_agent_name => "neutron-metadata-agent",
    :dhcp_agent_name => "neutron-dhcp-agent",
    :l3_agent_name => "neutron-l3-agent",
    :ovs_pkgs => [ "linux-headers-#{`uname -r`.strip}",
                   "openvswitch-datapath-dkms",
                   "openvswitch-switch" ],
    :cisco_pkgs => [ "" ],
    :user => "neutron",
    :ovs_modprobe => "modprobe openvswitch",
    :neutron_rootwrap_sudo_template => "/etc/sudoers.d/neutron-rootwrap"
  }
end
