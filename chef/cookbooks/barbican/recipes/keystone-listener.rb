#
# Copyright 2016 SUSE Linux GmbH
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
# Cookbook Name:: barbican
# Recipe:: keystone-listener
#

include_recipe "#{@cookbook_name}::common"

if node[:barbican][:enable_keystone_listener]
  package "openstack-barbican-keystone-listener"
end

use_crowbar_pacemaker_service = node[:barbican][:ha][:enabled] &&
  node[:pacemaker][:clone_stateless_services]

service "openstack-barbican-keystone-listener" do
  action [:enable, :start] if node[:barbican][:enable_keystone_listener]
  action [:disable, :stop] unless node[:barbican][:enable_keystone_listener]
  provider Chef::Provider::CrowbarPacemakerService if use_crowbar_pacemaker_service
end
utils_systemd_service_restart "openstack-barbican-keystone-listener" do
  action use_crowbar_pacemaker_service ? :disable : :enable
  only_if { node[:barbican][:enable_keystone_listener] }
end
