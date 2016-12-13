#
# Copyright 2016 SUSE Linux GmbH
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

### TODO: uncomment this once there is a package.
# package "openstack-monasca-agent"

### FIXME: remove this once there is a package creating this directory

directory "/etc/monasca/agent/" do
  owner "root"
  group "root"
  mode 0o755
  recursive true
  notifies :create, "template[/etc/monasca/agent/agent.yaml]"
end

### TODO:
# * populate agent_settings with useful values for monasca_url and keystone
#   settings
# * generate per-node keystone credentials in
#   crowbar_framework/app/models/monasca_service.rb
# * use credentials generated in the previous step to create a keystone account
#   here (using keystone_register)

agent_settings = node[:monasca][:agent][:config]

template "/etc/monasca/agent/agent.yaml" do
  source "agent.yaml.erb"
  owner "root"
  ### FIXME: Uncomment once we have a package that creates a monasca group
  # group node[:monasca][:group]
  mode 0o640
  variables agent_settings
  ### FIXME: Uncomment once we have a package that creates a monasca-agent service
  # notifies :reload, resources(service: "openstack-monasca-agent")
end

node.save
