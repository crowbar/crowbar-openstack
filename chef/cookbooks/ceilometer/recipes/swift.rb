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

unless node[:ceilometer][:use_gitrepo]
  package "openstack-ceilometer"
  package "openstack-swift-proxy" # we need it for swift user presence
else
  ceilometer_path = "/opt/ceilometer"
  venv_path = node[:ceilometer][:use_virtualenv] ? "#{ceilometer_path}/.venv" : nil
  venv_prefix = node[:ceilometer][:use_virtualenv] ? ". #{venv_path}/bin/activate &&" : nil
  pfs_and_install_deps "ceilometer" do
    cookbook "ceilometer"
    cnode node
    virtualenv venv_path
    path ceilometer_path
    wrap_bins [ "ceilometer" ]
  end
  create_user_and_dirs(@cookbook_name)
end

include_recipe "#{@cookbook_name}::common"

env_filter = " AND keystone_config_environment:keystone-config-#{node[:ceilometer][:keystone_instance]}"
keystones = search(:node, "recipes:keystone\\:\\:server#{env_filter}") || []
if keystones.length > 0
  keystone = keystones[0]
  keystone = node if keystone.name == node.name
else
  keystone = node
end

keystone_host = keystone[:fqdn]
keystone_protocol = keystone["keystone"]["api"]["protocol"]
keystone_token = keystone["keystone"]["service"]["token"]
keystone_admin_port = keystone["keystone"]["api"]["admin_port"]
keystone_service_tenant = keystone["keystone"]["service"]["tenant"]
keystone_service_user = node["ceilometer"]["keystone_service_user"]
Chef::Log.info("Keystone server found at #{keystone_host}")


keystone_register "give ceilometer user ResellerAdmin role" do
  protocol keystone_protocol
  host keystone_host
  port keystone_admin_port
  token keystone_token
  user_name keystone_service_user
  tenant_name keystone_service_tenant
  role_name "ResellerAdmin"
  action :add_access
end

# swift user needs read access to ceilometer.conf
group node[:ceilometer][:group] do
  action :modify
  members node[:swift][:user]
  append true
end

file "/var/log/ceilometer/swift-proxy-server.log" do
  owner node[:swift][:user]
  group node[:swift][:group]
  mode  "0644"
  action :create_if_missing
end
