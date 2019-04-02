# Copyright 2019, SUSE LINUX Products GmbH
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

define :octavia_service do
  package "openstack-octavia-#{params[:name]}" if ["rhel", "suse"].include? node[:platform_family]

  conf = if params[:name] == "api"
    "/etc/octavia/octavia.conf"
  else
    "/etc/octavia/octavia-#{params[:name]}.conf"
  end

  service "octavia-#{params[:name]}" do
    service_name "openstack-octavia-#{params[:name]}"
    supports status: true, restart: true
    action [:enable, :start]
    subscribes :restart, resources(template: conf)
  end

  utils_systemd_service_restart "openstack-octavia-#{params[:name]}"
end
