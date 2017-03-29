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

# the image is uploaded via the glance API so we need a glance-server
glance_server = node_search_with_cache("roles:glance-server").first
if glance_server.nil?
  Chef::Log.warn("No glance-server found. Can not upload #{service_sles_image_name}")
  return
end
# extra argument if the --insecure is needed when talking to glance-api
openstack_args_glance = (glance_server[:glance][:api][:protocol] == "https" &&
  glance_server[:glance][:ssl][:insecure]) || keystone_settings["insecure"] ? "--insecure" : ""

# the flavor is created via the nova API so we need a nova-controller
nova_controller = node_search_with_cache("roles:nova-controller").first
if nova_controller.nil?
  Chef::Log.warn("No nova-controller found. Can not create magnum flavors")
  return
end
# extra argument if the --insecure is needed when talking to nova-api
openstack_args_nova = (nova_controller[:nova][:ssl][:enabled] &&
  nova_controller[:nova][:ssl][:insecure]) || keystone_settings["insecure"] ? "--insecure" : ""


# create basic arguments for openstack client
openstack_args = "--os-username #{keystone_settings["service_user"]}"
openstack_args += " --os-auth-type password --os-identity-api-version 3"
openstack_args += " --os-password #{keystone_settings["service_password"]}"
openstack_args += " --os-tenant-name #{keystone_settings["service_tenant"]}"
openstack_args += " --os-auth-url #{keystone_settings["internal_auth_url"]}"
openstack_args += " --os-endpoint internalURL"

openstack_cmd = "openstack #{openstack_args}"

image_url = "http://#{provisioner_address}:8091/files/" \
  "#{service_sles_image_name}/" \
  "#{service_sles_image_name}.#{node[:kernel][:machine]}.qcow2"

execute "create_magnum_image" do
  command "curl #{image_url} | \
  #{openstack_cmd} #{openstack_args_glance} image create --disk-format qcow2 \
  --container-format bare --public --property os_distro=opensuse \
  #{service_sles_image_name}"
  not_if "#{openstack_cmd} #{openstack_args_glance} image list -f value -c Name | grep -q #{service_sles_image_name}"
  action :nothing
end

execute "create_magnum_flavor" do
  command "#{openstack_cmd} #{openstack_args_nova} flavor create --ram 1024 --disk 10 \
  --vcpus 1 m1.magnum"
  not_if "#{openstack_cmd} #{openstack_args_nova} flavor list --all | grep -q m1.magnum"
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
