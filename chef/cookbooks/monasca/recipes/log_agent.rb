# Copyright 2017 FUJITSU LIMITED
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

package "openstack-monasca-log-agent"

log_agent_settings = node[:monasca][:log_agent]
log_agent_keystone = log_agent_settings[:keystone]
keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)
log_filters_components = {
  openstack: ["aodh", "barbican", "ceilometer", "cinder", "glance", "heat",
              "keystone", "magnum", "manila", "neutron", "nova", "openvswitch",
              "sahara", "swift", "trove"
             ]
}

monasca_server = node_search_with_cache("roles:monasca-server").first
if monasca_server.nil?
  Chef::Log.warn("No monasca-server found. Skip monasca-log-agent setup.")
  return
end

log_agent_dimensions = {
  service: "monitoring",
  hostname: node["hostname"]
}

log_files = {
  "/var/log/messages" => "system",
  "/var/log/zypper.log" => "system"
}

log_filters = [
  {
    name: "multiline",
    type: "openstack",
    configuration: {
      pattern: "^%{TIMESTAMP_ISO8601}%{SPACE}%{NUMBER}%{SPACE}\
      (CRITICAL|ERROR|WARNING|INFO|DEBUG|EXCEPTION|NOTSET)",
      what: "previous",
      negate: "true"
    }
  }
]
ruby_block "find log files" do
  block do
    log_dirs =
      Dir.entries("/var/log")
         .select { |e| File.directory?("/var/log/#{e}") }
         .reject { |f| f["."] || f[/^monasca/] }
    log_dirs.each { |d| log_files["/var/log/#{d}/**/*.log"] = d.downcase }
  end
end

monasca_log_api_url = MonascaHelper.log_api_network_url(monasca_server)

template "/etc/monasca-log-agent/agent.conf" do
  source "log-agent.conf.erb"
  owner "root"
  group "root"
  mode 0o640
  variables(
    monasca_log_api_url: monasca_log_api_url,
    log_agent_keystone: log_agent_keystone,
    log_agent_settings: log_agent_settings,
    log_agent_dimensions: log_agent_dimensions,
    log_filters_components: log_filters_components,
    log_filters: log_filters,
    keystone_settings: keystone_settings,
    log_files: log_files
  )
  notifies :reload, "service[openstack-monasca-log-agent]"
end

service "openstack-monasca-log-agent" do
  supports status: true, restart: true, start: true, stop: true
  action [:enable, :start]
end

node.save
