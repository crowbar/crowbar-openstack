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

openstack_args = "--os-username #{keystone_settings["service_user"]}"
openstack_args += " --os-auth-type password --os-identity-api-version 3"
openstack_args += " --os-password #{keystone_settings["service_password"]}"
openstack_args += " --os-tenant-name #{keystone_settings["service_tenant"]}"
openstack_args += " --os-auth-url #{keystone_settings["internal_auth_url"]}"
openstack_args += " --os-endpoint internalURL"
openstack_args += keystone_settings["insecure"] ? "--insecure" : ""

openstack_cmd = "openstack #{openstack_args}"

admin_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "admin").address

execute "create_magnum_image" do
  command "curl http://#{admin_address}:8091/files/#{service_sles_image_name}/\
  #{service_sles_image_name}.#{node[:kernel][:machine]}.qcow2 | \
  #{openstack_cmd} image create  --disk-format qcow2 --container-format bare \
  --public --property os_distro=opensuse #{service_sles_image_name}"
  not_if "#{openstack_cmd} image list -f value -c Name | grep -q #{service_sles_image_name}"
  action :nothing
end

execute "create_magnum_flavor" do
  command "#{openstack_cmd} flavor create --ram 1024 --disk 10 --vcpus 1 m1.magnum"
  not_if "#{openstack_cmd} flavor list --all | grep -q m1.magnum"
  action :nothing
end

# This is to trigger the above resource to run :delayed, so that they run at
# the end of the chef-client run, after the magnum services have been restarted
# (in case of a config change)
execute "trigger-magnum-commands" do
  command "true"
  notifies :run, "execute[create_magnum_image]", :delayed
  notifies :run, "execute[create_magnum_flavor]", :delayed
end
