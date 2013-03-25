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

package "mongodb" do
  action :install
end

unless node[:ceilometer][:use_gitrepo]
  package "ceilometer-common" do
    action :install
  end
  package "ceilometer-collector" do
    action :install
  end
  package "ceilometer-api" do
    action :install
  end  
else
  ceilometer_path = "/opt/ceilometer"
  pfs_and_install_deps("ceilometer")
  link_service "ceilometer-collector"
  link_service "ceilometer-api"
  create_user_and_dirs("ceilometer") 
  execute "cp_policy.json" do
    command "cp #{ceilometer_path}/etc/policy.json /etc/ceilometer"
    creates "/etc/ceilometer/policy.json"
  end
  execute "cp_pipeline.yaml" do
    command "cp #{ceilometer_path}/etc/pipeline.yaml /etc/ceilometer"
    creates "/etc/ceilometer/pipeline.yaml"
  end
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

keystone_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(keystone, "admin").address if keystone_address.nil?
keystone_token = keystone["keystone"]["service"]["token"]
keystone_admin_port = keystone["keystone"]["api"]["admin_port"]
keystone_service_port = keystone["keystone"]["api"]["service_port"]
keystone_service_tenant = keystone["keystone"]["service"]["tenant"]
keystone_service_user = node["ceilometer"]["keystone_service_user"]
keystone_service_password = node["ceilometer"]["keystone_service_password"]
Chef::Log.info("Keystone server found at #{keystone_address}")

my_ipaddress = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "admin").address
pub_ipaddress = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "public").address rescue my_ipaddress

service "ceilometer-collector" do
  supports :status => true, :restart => true
  action :enable
  subscribes :restart, resources("template[/etc/ceilometer/ceilometer.conf]")
end

service "ceilometer-api" do
  supports :status => true, :restart => true
  action :enable
  subscribes :restart, resources("template[/etc/ceilometer/ceilometer.conf]")
end

keystone_register "register ceilometer user" do
  host keystone_address
  port keystone_admin_port
  token keystone_token
  user_name keystone_service_user
  user_password keystone_service_password
  tenant_name keystone_service_tenant
  action :add_user
end

keystone_register "give ceilometer user access" do
  host keystone_address
  port keystone_admin_port
  token keystone_token
  user_name keystone_service_user
  tenant_name keystone_service_tenant
  role_name "ResellerAdmin"
  action :add_access
end

# Create ceilometer service
keystone_register "register ceilometer service" do
  host my_ipaddress
  port node[:ceilometer][:api][:port]
  service_name "ceilometer"
  service_type "metering"
  service_description "Openstack Collector Service"
  action :add_service
end

keystone_register "register ceilometer endpoint" do
  host keystone_address
  port keystone_admin_port
  token keystone_token
  endpoint_service "ceilometer"
  endpoint_region "RegionOne"
  endpoint_publicURL "http://#{pub_ipaddress}:8777/"
  endpoint_adminURL "http://#{my_ipaddress}:8777/"
  endpoint_internalURL "http://#{my_ipaddress}:8777/"
#  endpoint_global true
#  endpoint_enabled true
  action :add_endpoint_template
end

node.save
