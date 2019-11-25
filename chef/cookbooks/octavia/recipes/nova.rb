# Copyright 2019, SUSE LLC.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require "chef/mixin/shell_out"


image = "openstack-octavia-amphora-image-x86_64"
ha_enabled = node[:octavia][:ha][:enabled]
package image if !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node)
octavia_config = Barclamp::Config.load("openstack", "octavia")
cmd = OctaviaHelper.get_openstack_command(node, octavia_config)

sec_group = node[:octavia][:amphora][:sec_group]
project_name = node[:octavia][:amphora][:project]

execute "create_security_group" do
  command "#{cmd} security group create #{sec_group} --project #{project_name} "\
    "--description \"Octavia Management Security Group\""
  not_if "out=$(#{cmd} security group list); [ $? != 0 ] || echo ${out} | grep -q ' #{sec_group} '"
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
  retries 5
  retry_delay 10
  action :run
end

execute "add_amphora_port_to_amphora_security_group" do
  command "#{cmd} security group rule create --protocol tcp --dst-port 9443:9443 #{sec_group}"
  not_if "out=$(#{cmd} security group show #{sec_group}); [ $? != 0 ] || echo ${out} | " \
    "grep -q \"'9443'\""
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
  retries 5
  retry_delay 10
  action :run
end

execute "add_ssh_to_amphora_security_group" do
  command "#{cmd} security group rule create --protocol tcp --dst-port 22:22 #{sec_group}"
  not_if "out=$(#{cmd} security group show #{sec_group}); [ $? != 0 ] || echo ${out} | " \
    "grep -q \"'22'\""
  only_if { node[:octavia][:amphora][:ssh_access] }
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
  retries 5
  retry_delay 10
  action :run
end

execute "add_icmp_to_amphora_security_group" do
  command "#{cmd} security group rule create --protocol icmp #{sec_group}"
  not_if "out=$(#{cmd} security group show #{sec_group}); [ $? != 0 ] || echo ${out} | " \
    "grep -q \"'icmp'\""
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
  retries 5
  retry_delay 10
  action :run
end

flavor = node[:octavia][:amphora][:flavor]

execute "create_amphora_flavor" do
  command "#{cmd} flavor create --public --ram 1024 --disk 2 --vcpus 1 #{flavor}"
  not_if "out=$(#{cmd} flavor list); [ $? != 0 ] || echo ${out} | grep -q ' #{flavor} '"
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
  retries 5
  retry_delay 10
  action :run
end

image_tag = node[:octavia][:amphora][:image_tag]

execute "create_amphora_image" do
  command "#{cmd} image create --disk-format qcow2 --container-format bare "\
    "--file $(rpm -ql #{image} | grep qcow2 | head -n 1) --tag #{image_tag} #{image_tag}"
  not_if "out=$(#{cmd} image list); [ $? != 0 ] || echo ${out} | grep -q ' #{image_tag} '"
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
  retries 5
  retry_delay 10
  action :run
end

# execute "create octavia user key" do
#   command "#{cmd} keypair create --public-key /root/.ssh/id_rsa.pub octavia-key"
#   not_if `#{cmd} keypair list | grep --quiet ' octavia-key '`
#   only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
#   action :run
# end

manage_net = node[:octavia][:amphora][:manage_net]
manage_cidr = node[:octavia][:amphora][:manage_cidr]

execute "create_octavia_management_network" do
  command "#{cmd} network create --project #{project_name} #{manage_net}"
  not_if "out=$(#{cmd} network list); [ $? != 0 ] || echo ${out} | grep -q ' #{manage_net} '"
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
  retries 5
  retry_delay 10
  action :run
end

execute "create_octavia_management_subnet" do
  command "#{cmd} subnet create --network #{manage_net} " \
      "--subnet-range #{manage_cidr} --project #{project_name} #{manage_net}"
  not_if "out=$(#{cmd} subnet list); [ $? != 0 ] || echo ${out} | grep -q ' #{manage_net} '"
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
  retries 5
  retry_delay 10
  action :run
end

execute "create listener port for health-manager" do
  command "#{cmd} port create " \
          "--network #{manage_net} " \
          "--security-group #{sec_group} " \
          "--device-owner Octavia:health-mgr " \
          "--host=$(hostname) " \
          "--description='Octavia Health Manager Listener Port' " \
          "lb-mgmt-listener-port"
  not_if "$(#{cmd} port list | grep -q ' lb-mgmt-listener-port ')"
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
  retries 5
  retry_delay 10
  action :run
end

neutron_server = node_search_with_cache("roles:neutron-server").first
Chef::Log.info("first neutron_server = #{neutron_server}")

ruby_block "Create interface to bridge to #{manage_net}" do
  block do
    port_id = shell_out("#{cmd} port show --column id --format value " \
                        "lb-mgmt-listener-port").stdout.chomp
    port_mac = shell_out("#{cmd} port show --column mac_address " \
                         "--format value lb-mgmt-listener-port").stdout.chomp
    port_ip = shell_out("#{cmd} port show --column fixed_ips --format value " \
                        "lb-mgmt-listener-port").stdout.chomp().match(/ip_address='([^']*).*$/)[1]

    Chef::Log.info("port_id = #{port_id}")
    Chef::Log.info("port_mac = #{port_mac}")
    Chef::Log.info("port_ip = #{port_ip}")

    Chef::Log.info("server[:neutron][:ml2_mechanism_drivers]: " \
                   "#{neutron_server[:neutron][:ml2_mechanism_drivers]}")

    if neutron_server[:neutron][:networking_plugin] == "ml2" && \
       neutron_server[:neutron][:ml2_mechanism_drivers].include?("linuxbridge")
      shell_out("ip link add o-hm0 type veth peer name o-bhm0") \
        unless system("ip link show o-hm0 > /dev/null 2>&1")
      net_id = shell_out("#{cmd} network show #{manage_net} " \
                         "--column id --format value").stdout.chomp
      bridge_name = "brq" + net_id[0..10]
      Chef::Log.info("net_id = #{net_id}")
      Chef::Log.info("bridge_name = #{bridge_name}")
      shell_out("brctl addif #{bridge_name} o-bhm0") \
        unless system("brctl show #{bridge_name} | grep --quiet o-bhm0")
      shell_out("ip link set o-bhm0 up")
    else
      Chef::Log.info("Not using linuxbridge")
    end
    Chef::Log.info("Setting MAC address of veth port")
    shell_out("ip link set dev o-hm0 address #{port_mac}")

    Chef::Log.info("Setting IP address of veth port")
    shell_out("ip address add #{port_ip}/16 dev o-hm0")
    shell_out("ip link set o-hm0 up")

    shell_out("iptables --insert INPUT -i o-hm0 -p udp --dport 5555 -j ACCEPT") \
      unless system("iptables --check INPUT -i o-hm0 -p udp --dport 5555 -j ACCEPT")
    shell_out("iptables -I INPUT -i o-hm0 -p udp --dport 10514 -j ACCEPT") \
      unless system("iptables --check INPUT -i o-hm0 -p udp --dport 10514 -j ACCEPT")
    shell_out("iptables -I INPUT -i o-hm0 -p udp --dport 20514 -j ACCEPT") \
      unless system("iptables --check INPUT -i o-hm0 -p udp --dport 20514 -j ACCEPT")
  end
end

# Installing the amphora image package and creating OpenStack artifacts (the
# security group, image, network etc.) can take a lot of time, so we have to
# account for the fact that nodes will fall out of sync in an HA setup.
# We do an explicit sync here with an extended timeout value, to avoid having
# timeout failures un subsequent sync marks (the octavia_database sync mark).
if ha_enabled
  crowbar_pacemaker_sync_mark "sync-octavia_after_long_ops" do
    timeout 200
  end
end
