#Copyright 2016, SUSE Linux GmbH
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

define :octavia_service do
 # ha_enabled = node[:octavia][:ha][:enabled]

 package "openstack-octavia-#{params[:name]}" if ["rhel", "suse"].include? node[:platform_family]

 if params[:name] == "api"
   conf = "/etc/octavia/octavia.conf"
 else
   conf = "/etc/octavia/octavia-#{params[:name]}.conf"
 end
 
 service "octavia-#{params[:name]}" do
   service_name "openstack-octavia-#{params[:name]}"
   supports status: true, restart: true
   action [:enable, :start]
   subscribes :restart, resources(template: conf)
  #TODO provider Chef::Provider::CrowbarPacemakerService if ha_enabled
 end
end
