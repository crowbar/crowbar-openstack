#
# Copyright 2016 SUSE LINUX GmbH
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

node[:neutron][:platform][:odl_pkgs].each { |p| package p }

odl_controller_ip = node[:neutron][:odl][:controller_ip]
odl_controller_port = node[:neutron][:odl][:controller_port]
odl_url = "http://#{odl_controller_ip}:#{odl_controller_port}/controller/nb/v2/neutron"

template "/etc/neutron/plugins/ml2/ml2_conf_odl.ini" do
  cookbook "neutron"
  source "ml2_conf_odl.ini.erb"
  mode "0640"
  owner "root"
  group node[:neutron][:platform][:group]
  variables(
    ml2_odl_url: odl_url,
    ml2_odl_username: node[:neutron][:odl][:username],
    ml2_odl_password: node[:neutron][:odl][:password]
  )
  notifies :restart, "service[#{node[:neutron][:platform][:service_name]}]"
end
