
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

default[:quantum][:debug] = false
default[:quantum][:verbose] = false
default[:quantum][:dhcp_domain] = "openstack.local"
default[:quantum][:networking_mode] = "local"
default[:quantum][:networking_plugin] = "openvswitch"

default[:quantum][:db][:database] = "quantum"
default[:quantum][:db][:user] = "quantum"
default[:quantum][:db][:password] = "" # Set by Recipe
default[:quantum][:db][:ovs_database] = "ovs"
default[:quantum][:db][:ovs_user] = "ovs"
default[:quantum][:db][:ovs_password] = "" # Set by Recipe
default[:quantum][:network][:fixed_router] = "127.0.0.1" # Set by Recipe
default[:quantum][:network][:private_networks] = [] # Set by Recipe
# Default range for GRE tunnels
default[:quantum][:network][:gre_start] = 1
default[:quantum][:network][:gre_stop] = 1000


default[:quantum][:api][:protocol] = "http"
default[:quantum][:api][:service_port] = "9696"
default[:quantum][:api][:service_host] = "0.0.0.0"

default[:quantum][:sql][:idle_timeout] = 30
default[:quantum][:sql][:min_pool_size] = 5
default[:quantum][:sql][:max_pool_size] = 10
default[:quantum][:sql][:pool_timeout] = 200

default[:quantum][:ssl][:certfile] = "/etc/quantum/ssl/certs/signing_cert.pem"
default[:quantum][:ssl][:keyfile] = "/etc/quantum/ssl/private/signing_key.pem"
default[:quantum][:ssl][:generate_certs] = false
default[:quantum][:ssl][:insecure] = false
default[:quantum][:ssl][:cert_required] = false
default[:quantum][:ssl][:ca_certs] = "/etc/quantum/ssl/certs/ca.pem"

default[:quantum][:quantum_server] = false


case node["platform"]
when "suse"
  default[:quantum][:platform] = {
    :pkgs => [ "openstack-quantum-server",
               "openstack-quantum-l3-agent",
               "openstack-quantum-dhcp-agent",
               "openstack-quantum-metadata-agent" ],
    :service_name => "openstack-quantum",
    :ovs_agent_pkg => "openstack-quantum-openvswitch-agent",
    :ovs_agent_name => "openstack-quantum-openvswitch-agent",
    :lb_agent_pkg => "openstack-quantum-linuxbridge-agent",
    :lb_agent_name => "openstack-quantum-linuxbridge-agent",
    :metadata_agent_name => "openstack-quantum-metadata-agent",
    :dhcp_agent_name => "openstack-quantum-dhcp-agent",
    :l3_agent_name => "openstack-quantum-l3-agent",
    :ovs_pkgs => [ "openvswitch",
                   "openvswitch-switch",
                   "openvswitch-kmp-default" ],
    :user => "openstack-quantum",
    :ovs_modprobe => "modprobe openvswitch",
    :quantum_rootwrap_sudo_template => "/etc/sudoers.d/openstack-quantum"
  }
when "centos", "redhat"
  default[:quantum][:platform] = {
    :pkgs => [ "openstack-quantum" ],
    :service_name => "quantum-server",
    :ovs_agent_pkg => "openstack-quantum-openvswitch",
    :ovs_agent_name => "quantum-openvswitch-agent",
    :lb_agent_pkg => "openstack-quantum-linuxbridge",
    :lb_agent_name => "openstack-quantum-linuxbridge-agent",
    :metadata_agent_name => "quantum-metadata-agent",
    :dhcp_agent_name => "quantum-dhcp-agent",
    :l3_agent_name => "quantum-l3-agent",
    :ovs_pkgs => [ "openvswitch",
                   "openstack-quantum-openvswitch" ],
    :user => "quantum",
    :ovs_modprobe => "modprobe openvswitch",
    :quantum_rootwrap_sudo_template => "/etc/sudoers.d/openstack-quantum"
  }
else
  default[:quantum][:platform] = {
    :pkgs => [ "quantum-server",
               "quantum-l3-agent",
               "quantum-dhcp-agent",
               "quantum-plugin-openvswitch",
               "quantum-metadata-agent" ],
    :service_name => "quantum-server",
    :ovs_agent_pkg => "quantum-plugin-openvswitch-agent",
    :ovs_agent_name => "quantum-plugin-openvswitch",
    :lb_agent_pkg => "quantum-plugin-linuxbridge-agent",
    :lb_agent_name => "quantum-plugin-linuxbridge-agent",
    :metadata_agent_name => "quantum-metadata-agent",
    :dhcp_agent_name => "quantum-dhcp-agent",
    :l3_agent_name => "quantum-l3-agent",
    :ovs_pkgs => [ "linux-headers-#{`uname -r`.strip}",
                   "openvswitch-datapath-dkms",
                   "openvswitch-switch" ],
    :user => "quantum",
    :ovs_modprobe => "modprobe openvswitch",
    :quantum_rootwrap_sudo_template => "/etc/sudoers.d/quantum-rootwrap"
  }
end
