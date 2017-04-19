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

package "openstack-monasca-agent"

agent_settings = node[:monasca][:metric_agent]
agent_keystone = agent_settings[:keystone]

keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)

monasca_server = node_search_with_cache("roles:monasca-server").first
if monasca_server.nil?
  Chef::Log.warn("No monasca-server found.")
  return
end

monasca_api_url = MonascaHelper.api_public_url(monasca_server)

agent_dimensions = { service: "monitoring" }
service = "monitoring"

monasca_reconfigure_file = "/usr/sbin/monasca-reconfigure"

template monasca_reconfigure_file do
  source "monasca-reconfigure.erb"
  owner "root"
  group "root"
  mode 0o750
  variables(
    monasca_api_url: monasca_api_url,
    service: service,
    agent_settings: agent_settings,
    agent_keystone: agent_keystone,
    keystone_settings: keystone_settings,
    agent_dimensions: agent_dimensions,
    install_plugins_only: false
  )
  notifies :run, "execute[monasca-setup detect services]", :delayed
end

execute "monasca-setup detect services" do
  command monasca_reconfigure_file
  user "root"
  group "root"
  action :nothing
end

service "monasca-metric-agent" do
  service_name agent_settings[:service_name]
  supports status: true, restart: true, start: true, stop: true
  action [:enable, :start]
  ignore_failure true
  # provider Chef::Provider::CrowbarPacemakerService if ha_enabled
end

node.save
