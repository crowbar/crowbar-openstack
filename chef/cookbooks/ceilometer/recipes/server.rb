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
  role_name "ResselerAdmin"
  action :add_access
end

# Create ceilometer service
ceilometer_register "register ceilometer service" do
  host my_ipaddress
  port node[:ceilometer][:api][:port]
  service_name "ceilometer"
  service_type "metering"
  service_description "Openstack Collector Service"
  action :add_service
end

node.save
