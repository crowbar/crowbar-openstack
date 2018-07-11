# Copyright 2018, SUSE Linux GmbH
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

define :designate_service do
  designate_service_name = "designate-#{params[:name]}"
  ha_enabled = node[:designate][:ha][:enabled]
  use_crowbar_pacemaker_service = ha_enabled && node[:pacemaker][:clone_stateless_services]

  package "openstack-designate-#{params[:name]}"

  service designate_service_name do
    service_name "openstack-#{designate_service_name}"
    supports status: true, restart: true
    action [:enable, :start]
    subscribes :restart, resources(template: node[:designate][:config_file])
    provider Chef::Provider::CrowbarPacemakerService if use_crowbar_pacemaker_service
  end
  utils_systemd_service_restart designate_service_name do
    action use_crowbar_pacemaker_service ? :disable : :enable
  end
end
