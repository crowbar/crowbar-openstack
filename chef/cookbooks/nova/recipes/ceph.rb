#
# Copyright (c) 2015 SUSE Linux GmbH.
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
# Cookbook Name:: nova
# Recipe:: ceph
#

has_internal = false
has_external = false

cinder_controller = node_search_with_cache("roles:cinder-controller").first
return if cinder_controller.nil?

has_ses = SesHelper.populate_cinder_volumes_with_ses_settings(cinder_controller)
ses_config = SesHelper.ses_settings

# Install SES based ceph configuration
if has_ses
  ses_config "nova" do
    action :create
  end
end

# find if we have internal/external cluster
cinder_controller[:cinder][:volumes].each_with_index do |volume, volid|
  next unless volume[:backend_driver] == "rbd"

  has_internal ||= true if volume[:rbd][:use_crowbar]
  has_external ||= true unless volume[:rbd][:use_crowbar]
end

if has_internal
  ceph_env_filter = " AND ceph_config_environment:ceph-config-default"
  ceph_servers = search(:node, "roles:ceph-osd#{ceph_env_filter}") || []
  if ceph_servers.length > 0
    include_recipe "ceph::keyring"
  else
    message = "Ceph was not deployed with Crowbar yet!"
    Chef::Log.fatal(message)
    raise message
  end
end

if has_external || has_ses
  # Ensure ceph is available here
  if node[:platform_family] == "suse"
    # install package in compile phase because we will run "ceph -s"
    package "ceph-common" do
      action :nothing
    end.run_action(:install)
  end
end
