#
# Copyright 2019 SUSE
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
# Cookbook Name:: ironic
# Recipe:: post_install
#

keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)

# the image is uploaded via the glance API
glance_config = Barclamp::Config.load("openstack", "glance", node[:ironic][:glance_instance])
glance_insecure = CrowbarOpenStackHelper.insecure(glance_config)
openstack_args_glance = glance_insecure || keystone_settings["insecure"] ? "--insecure" : ""

env = "OS_USERNAME='#{keystone_settings["service_user"]}' "
env << "OS_PASSWORD='#{keystone_settings["service_password"]}' "
env << "OS_PROJECT_NAME='#{keystone_settings["service_tenant"]}' "
env << "OS_AUTH_URL='#{keystone_settings["internal_auth_url"]}' "
env << "OS_INTERFACE=internal "
env << "OS_IDENTITY_API_VERSION=3 "

kernel_image_prefix = "ir-deploy-kernel"
ramdisk_image_prefix = "ir-deploy-ramdisk"
image_path = "/srv/tftpboot/openstack-ironic-image"

# vmlinux symlink from openstack-ironic-image points to something like:
#   openstack-ironic-image.x86_64-9.0.0.kernel.4.12.14-95.13-default
# find all x.y.z version substrings and pick the first one to be used
# as version suffix
image_version_cmd = "$(readlink #{image_path}/vmlinux | egrep -o '[0-9]+\\.[0-9]+\\.[0-9]+' | head -n1)"

openstack_cmd = "#{env} openstack"

bash "upload_ironic_deploy_kernel_image" do
  code "#{openstack_cmd} #{openstack_args_glance} image create \
  --disk-format aki --container-format aki --public \
  --file #{image_path}/vmlinux #{kernel_image_prefix}-#{image_version_cmd}"
  not_if "#{openstack_cmd} #{openstack_args_glance} image list -f value -c Name | grep -q #{kernel_image_prefix}-#{image_version_cmd}"
  action :nothing
end

bash "upload_ironic_deploy_ramdisk_image" do
  code "#{openstack_cmd} #{openstack_args_glance} image create \
  --disk-format ari --container-format ari --public \
  --file #{image_path}/initrd #{ramdisk_image_prefix}-#{image_version_cmd}"
  not_if "#{openstack_cmd} #{openstack_args_glance} image list -f value -c Name | grep -q #{ramdisk_image_prefix}-#{image_version_cmd}"
  action :nothing
end

# This is to trigger the above resource to run :delayed, so that they run at
# the end of the chef-client run, after the ironic services have been restarted
# (in case of a config change)
execute "trigger-ironic-post-commands" do
  command "true"
  notifies :run, "bash[upload_ironic_deploy_kernel_image]", :delayed
  notifies :run, "bash[upload_ironic_deploy_ramdisk_image]", :delayed
end
