#
# Copyright 2017 SUSE Linux GmbH
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
# Cookbook Name:: magnum
# Recipe:: post_install
#

return unless !node[:magnum][:ha][:enabled] || CrowbarPacemakerHelper.is_cluster_founder?(node)

keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)

service_sles_image_name = "openstack-magnum-k8s-image"

# the image is served by the provisioner-server so we need a provisioner
provisioner_server = node_search_with_cache("roles:provisioner-server").first
if provisioner_server.nil?
  Chef::Log.warn("No provisioner-server found. Can not fetch #{service_sles_image_name}")
  return
end
provisioner_address = Barclamp::Inventory.get_network_by_type(provisioner_server, "admin").address

# the image is uploaded via the glance API
glance_config = Barclamp::Config.load("openstack", "glance", node[:magnum][:glance_instance])
glance_insecure = CrowbarOpenStackHelper.insecure(glance_config)
openstack_args_glance = glance_insecure || keystone_settings["insecure"] ? "--insecure" : ""

# the flavor is created via the nova API
nova_config = Barclamp::Config.load("openstack", "nova", node[:magnum][:nova_instance])
nova_insecure = CrowbarOpenStackHelper.insecure(nova_config)
openstack_args_nova = nova_insecure || keystone_settings["insecure"] ? "--insecure" : ""

env = "OS_USERNAME='#{keystone_settings["service_user"]}' "
env << "OS_PASSWORD='#{keystone_settings["service_password"]}' "
env << "OS_PROJECT_NAME='#{keystone_settings["service_tenant"]}' "
env << "OS_AUTH_URL='#{keystone_settings["internal_auth_url"]}' "
env << "OS_INTERFACE=internal "
env << "OS_IDENTITY_API_VERSION=3"

openstack_cmd = "#{env} openstack"

image_url = "http://#{provisioner_address}:8091/files/" \
  "#{service_sles_image_name}/" \
  "#{service_sles_image_name}.#{node[:kernel][:machine]}.qcow2"

execute "create_magnum_image" do
  command "curl #{image_url} | \
  #{openstack_cmd} #{openstack_args_glance} image create --disk-format qcow2 \
  --container-format bare --public --property os_distro=opensuse \
  #{service_sles_image_name}"
  not_if "#{openstack_cmd} #{openstack_args_glance} image list -f value -c Name | grep -q #{service_sles_image_name}"
  retries 5
  retry_delay 10
  action :nothing
end

execute "create_magnum_flavor" do
  command "#{openstack_cmd} #{openstack_args_nova} flavor create --ram 1024 --disk 10 \
  --vcpus 1 m1.magnum"
  not_if "#{openstack_cmd} #{openstack_args_nova} flavor list --all | grep -q m1.magnum"
  retries 5
  retry_delay 10
  action :nothing
end

# This is to trigger the above resource to run :delayed, so that they run at
# the end of the chef-client run, after the magnum services have been restarted
# (in case of a config change)
execute "trigger-magnum-post-commands" do
  command "true"
  notifies :run, "execute[create_magnum_image]", :delayed
  notifies :run, "execute[create_magnum_flavor]", :delayed
end
