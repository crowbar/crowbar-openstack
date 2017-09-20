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
# Recipe:: worker
#

include_recipe "#{@cookbook_name}::common"

package "openstack-barbican-worker"

use_crowbar_pacemaker_service = node[:barbican][:ha][:enabled] &&
  node[:pacemaker][:clone_stateless_services]

service "openstack-barbican-worker" do
  action [:enable, :start]
  provider Chef::Provider::CrowbarPacemakerService if use_crowbar_pacemaker_service
end
