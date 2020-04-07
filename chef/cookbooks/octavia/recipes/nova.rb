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
require "ipaddr"

def mask_to_bits(mask)
  IPAddr.new(mask).to_i.to_s(2).count("1")
end

image = "openstack-octavia-amphora-image-x86_64"
ha_enabled = node[:octavia][:ha][:enabled]
package image if !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node)
cmd = OctaviaHelper.get_openstack_command(node, node[:octavia])

sec_group = node[:octavia][:amphora][:sec_group]
project_name = node[:octavia][:amphora][:project]

execute "create_security_group" do
  command "#{cmd} security group create #{sec_group} --project #{project_name} "\
    "--description \"Octavia Management Security Group\""
  not_if "out=$(#{cmd} security group list); [ $? != 0 ] || echo ${out} | " \
         "grep -q ' #{sec_group} '"
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

ruby_block "create_amphora_image" do
  block do
    image_packagename = shell_out("rpm -qa | grep #{image}").stdout.chomp
    image_qcow = shell_out("rpm -ql #{image} | grep qcow2").stdout.chomp
    images = shell_out("#{cmd} image list --tag #{image_tag} --sort created_at:asc " \
                       "--format value --column ID").stdout.split
    old_images = shell_out("#{cmd} image list --tag #{image_tag}-old --sort created_at:asc " \
                           "--format value --column ID").stdout.split
    image_md5 = shell_out("md5sum #{image_qcow}").stdout.split[0]
    latest_md5 = shell_out("#{cmd} image show --format value --column checksum " \
                           "#{images[-1]}").stdout.chomp
    if latest_md5 == image_md5
      # Remove latest image so we don't untag it later.
      images.pop
    else
      shell_out("#{cmd} image create --disk-format qcow2 " \
                "--container-format bare --file #{image_qcow} " \
                "--tag #{image_tag} #{image_packagename}")
    end
    (old_images + images).each do |old_image|
      servers_using_image = shell_out("#{cmd} server list " \
                                      "--image #{old_image} " \
                                      "--format value --column ID").stdout.split
      if servers_using_image.empty?
        Chef::Log.info("removing old image #{old_image}")
        shell_out("#{cmd} image delete #{old_image}")
      else
        # Only untag the image but do not delete it so that live
        # migration of amphorae using this image can still work. Note
        # that new amphorae will not use this image because it is
        # lacking the proper tag.
        Chef::Log.info("image #{old_image} still in use; untagging it")
        shell_out("#{cmd} image set --tag #{image_tag}-old #{old_image}")
        shell_out("#{cmd} image unset --tag #{image_tag} #{old_image}")
      end
    end
  end
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

# If the octavia network is configured in the network barclamp, use it to
# configure the management network and derive the attributes from the
# network attributes
octavia_net = Barclamp::Inventory.get_network_definition(node, "octavia")
unless octavia_net.nil?
  octavia_net_ranges = octavia_net["ranges"]
  octavia_range = "#{octavia_net["subnet"]}/#{mask_to_bits(octavia_net["netmask"])}"
  octavia_pool_start = octavia_net_ranges[:dhcp][:start]
  octavia_pool_end = octavia_net_ranges[:dhcp][:end]
  octavia_first_ip = IPAddr.new(octavia_range).to_range.to_a[2]
  octavia_last_ip = IPAddr.new(octavia_range).to_range.to_a[-2]

  octavia_pool_start = octavia_first_ip if octavia_first_ip > octavia_pool_start
  octavia_pool_end = octavia_last_ip if octavia_last_ip < octavia_pool_end

  octavia_netname = node[:octavia][:amphora][:manage_net]
  octavia_project = node[:octavia][:amphora][:project]

  # find the neutron network node, to figure out the right "physnet" parameter
  network_node = NeutronHelper.get_network_node_from_neutron_attributes(node)
  physnet_map = NeutronHelper.get_neutron_physnets(network_node, ["octavia"])
  octavia_network_type = "--provider-network-type flat " \
      "--provider-physical-network #{physnet_map["octavia"]}"

  execute "create_octavia_management_network" do
    command "#{cmd} network create " \
            "--project #{octavia_project} " \
            "--internal " \
            "#{octavia_network_type} #{octavia_netname}"
    only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
    not_if "out=$(#{cmd} network list); [ $? != 0 ] || echo ${out} " \
           "| grep -q ' #{octavia_netname} '"
    retries 5
    retry_delay 10
    action :run
  end

  execute "create_octavia_management_subnet" do
    command "#{cmd} subnet create " \
            "--project #{octavia_project} " \
            "--network #{octavia_netname} " \
            "--subnet-range #{octavia_range} " \
            "--allocation-pool start=#{octavia_pool_start},end=#{octavia_pool_end} " \
            "--gateway none " \
            "--dhcp " \
            "#{octavia_netname}"
    only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
    not_if "out=$(#{cmd} subnet list); [ $? != 0 ] || echo ${out} " \
           "| grep -q ' #{octavia_netname} '"
    retries 5
    retry_delay 10
    action :run
  end
end

# Installing the amphora image package and creating OpenStack artifacts (the
# security group, image, network etc.) can take a lot of time, so we have to
# account for the fact that nodes will fall out of sync in an HA setup.
# We do an explicit sync here with an extended timeout value, to avoid having
# timeout failures un subsequent sync marks (the octavia_database sync mark).
if ha_enabled
  crowbar_pacemaker_sync_mark "sync-octavia_after_long_ops" do
    timeout 300
  end
end
