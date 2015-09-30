# Copyright 2011 Dell, Inc.
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

package "ceilometer-agent-compute" do
  if %w(suse).include?(node[:platform_family])
    package_name "openstack-ceilometer-agent-compute"
  elsif %w(rhel).include?(node[:platform_family])
    package_name "openstack-ceilometer-compute"
  end
  action :install
end

include_recipe "#{@cookbook_name}::common"

is_compute = node.roles.any?{ |role| /^nova-multi-compute-/ =~ role }

service "ceilometer-agent-compute" do
  if %w(suse).include?(node[:platform_family])
    service_name "openstack-ceilometer-agent-compute"
  elsif %w(rhel).include?(node[:platform_family])
    service_name "openstack-ceilometer-compute"
  end
  supports status: true, restart: true
  if is_compute
    action [:enable, :start]
    subscribes :restart, resources("template[/etc/ceilometer/ceilometer.conf]")
    subscribes :restart, resources("template[/etc/ceilometer/pipeline.yaml]")
  else
    action [:disable, :stop]
  end
end
