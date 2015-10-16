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

package "ceilometer-agent-central" do
  if %w(suse).include?(node[:platform_family])
    package_name "openstack-ceilometer-agent-central"
  elsif %w(rhel).include?(node[:platform_family])
    package_name "openstack-ceilometer-central"
  end
  action :install
end

include_recipe "#{@cookbook_name}::common"

ha_enabled = node[:ceilometer][:ha][:central][:enabled]

service "ceilometer-agent-central" do
  service_name node[:ceilometer][:central][:service_name]
  supports status: true, restart: true, start: true, stop: true
  action [:enable, :start]
  subscribes :restart, resources("template[/etc/ceilometer/ceilometer.conf]")
  subscribes :restart, resources("template[/etc/ceilometer/pipeline.yaml]")
  provider Chef::Provider::CrowbarPacemakerService if ha_enabled
end

if ha_enabled
  log "HA support for ceilometer-central is enabled"
  include_recipe "ceilometer::central_ha"
else
  log "HA support for ceilometer-central is disabled"
end
