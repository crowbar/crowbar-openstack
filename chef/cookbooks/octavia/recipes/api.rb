# Copyright 2019 SUSE Linux, GmbH.
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
service_name = "octavia-api"
octavia_service_cmd = "octavia-api"
octavia_service_cmd_args = "--config-file={{ octavia_conf_dir }}/octavia-api.conf"

package "openstack-octavia-api"

file node[:octavia][:octavia_log_dir] + "/octavia-api.log" do
  action :touch
  owner node[:octavia][:user]
  group node[:octavia][:group]
  mode 00640
end

file node[:octavia][:octavia_log_dir] + "/octavia-api-json.log" do
  action :touch
  owner node[:octavia][:user]
  group node[:octavia][:group]
  mode 00640
end

octavia_component_exec_start = node[:octavia]["octavia_bin_dir"] + "/" + octavia_service_cmd + " " + octavia_service_cmd_args

template "/etc/systemd/system/#{service_name}.service" do
  source "octavia-component.service.erb"
  mode "0644"
  owner "root"
  group "root"
  variables(
    service_name: service_name,
    octavia_component_exec_start: octavia_component_exec_start
  )
end

bash "reload systemd after #{service_name} update" do
  code "systemctl daemon-reload"
  action :nothing
  subscribes :run,
    "template[/etc/systemd/system/#{service_name}.service]",
    :immediately
end

service "#{service_name}" do
  supports status: true, restart: true
  action [:enable, :start]
  subscribes :restart, resources(template: node[:neutron][:config_file])
end



# template node[:neutron][:nsx_config_file] do
#   cookbook "neutron"
#   source "nsx.ini.erb"
#   owner "root"
#   group node[:neutron][:platform][:group]
#   mode "0640"
#   variables(
#     vmware_config: node[:neutron][:vmware]
#   )
#   notifies :restart, "service[#{node[:neutron][:platform][:service_name]}]"
# end
