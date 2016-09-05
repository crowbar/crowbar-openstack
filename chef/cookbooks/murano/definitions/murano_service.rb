# Copyright 2017, SUSE Linux GmbH
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

define :murano_service do
  murano_service_name = "murano-#{params[:name]}"
  ha_enabled = node[:murano][:ha][:enabled]

  package "openstack-murano-#{params[:name]}" if ["rhel", "suse"].include? node[:platform_family]

  service murano_service_name do
    service_name "openstack-#{murano_service_name}"
    supports status: true, restart: true
    action [:enable, :start]
    subscribes :restart, resources(template: "/etc/murano/murano.conf")
    provider Chef::Provider::CrowbarPacemakerService if ha_enabled
  end
end
