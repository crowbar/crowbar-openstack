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
  package "ceilometer-agent-central" do
    action :install
  end
else
  ceilometer_path = "/opt/ceilometer"
  pfs_and_install_deps("ceilometer")
  link_service "ceilometer-agent-central"
  create_user_and_dirs(ceilometer-agent-central) 
  execute "cp_policy.json" do
    command "cp #{ceilometer_path}/etc/policy.json /etc/ceilometer"
    creates "/etc/ceilometer/policy.json"
  end
  execute "cp_pipeline.yaml" do
    command "cp #{ceilometer_path}/etc/pipeline.yaml /etc/ceilometer"
    creates "/etc/ceilometer/pipeline.yaml"
  end
end

service "ceilometer-agent-central" do
  supports :status => true, :restart => true
  action :enable
end

include_recipe "#{@cookbook_name}::common"

# Create ceilometer service
  ceilometer_register "register ceilometer service" do
  host my_ipaddress
  #port node[:ceilometer][:api][:port]
  service_name "ceilometer-agent-central"
  service_type "collector"
  service_description "Openstack Collector Service"
  action :add_service
end

node.save
