#
# Copyright 2012 Dell, Inc.
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
# Cookbook Name:: cinder
# Recipe:: scheduler
#

include_recipe "#{@cookbook_name}::common"

cinder_service "scheduler" do
  use_pacemaker_provider node[:cinder][:ha][:enabled]
end

service = "openstack-cinder-scheduler"
if node[:cinder][:resource_limits] && node[:cinder][:resource_limits][service]
  limits = node[:cinder][:resource_limits][service]
  action = limits.values.any? ? :create : :delete
  crowbar_openstack_systemd_override "Resource limits for #{service}" do
    service_name service
    limits limits
    action action
  end
end
