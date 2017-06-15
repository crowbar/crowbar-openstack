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

agent_settings = node[:monasca][:agent]
agent_keystone = agent_settings[:keystone]

keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)

monasca_server = node_search_with_cache("roles:monasca-server").first
if monasca_server.nil?
  Chef::Log.warn("No monasca-server found. Skip monasca-agent setup.")
  return
end

agent_dimensions = { service: "monitoring" }

monasca_api_url = MonascaHelper.api_network_url(monasca_server)
monasca_log_api_url = MonascaHelper.log_api_network_url(monasca_server) + '/healthcheck'
kibana_url = "http://" + MonascaHelper.monasca_public_host(monasca_server) + ":5601"
monasca_net_ip = MonascaHelper.get_host_for_monitoring_url(monasca_server)

if node["roles"].include?("monasca-server")
  # Special monasca-reconfigure script for monasca-server: on this machine
  # monasca-reconfigure will configure the agent.
  template "/usr/sbin/monasca-reconfigure" do
    source "monasca-reconfigure-server.erb"
    owner "root"
    group "root"
    mode "0750"
    variables(
      monasca_api_url: monasca_api_url,
      # Use monasca_api_url for the log API as well since both are just
      # different vhosts on the same web server and the monasca-agent Keystone
      # user is not allowed to access monasca-log-api:
      monasca_log_api_url: monasca_api_url,
      kibana_url: kibana_url,
      service: "monitoring",
      agent_settings: agent_settings,
      agent_keystone: agent_keystone,
      keystone_settings: keystone_settings,
      agent_dimensions: agent_dimensions,
      setup: node[:monasca][:setup]
    )
  end

  service agent_settings[:agent_service_name] do
    service_name agent_settings[:agent_service_name]
    supports status: true, restart: true, start: true, stop: true
    action [:enable, :start]
    # provider Chef::Provider::CrowbarPacemakerService if ha_enabled
  end

  monasca_agent_plugin_elastic "elasticsearch checks" do
    built_by "agent.rb"
    name "elasticsearch"
    url "http://#{monasca_net_ip}:9200"
  end

  execute "run monasca-reconfigure" do
    command "/usr/sbin/monasca-reconfigure"
  end

  # Nothing left to do, monasca-reconfigure has configured everything we need.
  return
else
  # Regular monasca-reconfigure script. if you use that script, the chef settings
  # will be overwritten and after the next chef-client run, the settings
  # from monasca-reconfigure will be overwritten. So DO NOT USE IT!
  template "/usr/sbin/monasca-reconfigure" do
    source "monasca-reconfigure.erb"
    owner "root"
    group "root"
    mode "0750"
    variables(
      monasca_api_url: monasca_api_url,
      service: "monitoring",
      agent_settings: agent_settings,
      agent_keystone: agent_keystone,
      keystone_settings: keystone_settings,
      agent_dimensions: agent_dimensions,
      setup: node[:monasca][:setup]
    )
  end

end

# the monasca-agent configuration
template "/etc/monasca/agent/agent.yaml" do
  source "monasca-agent_agent.yaml.erb"
  owner agent_settings[:user]
  group agent_settings[:group]
  mode "0640"
  variables(
    hostname: node[:hostname],
    monasca_api_url: monasca_api_url,
    agent_dimensions: agent_dimensions,
    log_dir: agent_settings["log_dir"],
    log_level: agent_settings[:log_level],
    keystone_settings: keystone_settings,
    agent_settings: agent_settings
  )
end

# monasca-agent uses supervisord to start multiple processes (forwarder, statsd, collector)
template "/etc/monasca/agent/supervisor.conf" do
  source "monasca-agent_supervisor.conf.erb"
  owner agent_settings[:user]
  group agent_settings[:group]
  mode "0640"
end

# enable and start the monasca-agent
service agent_settings[:agent_service_name] do
  service_name agent_settings[:agent_service_name]
  supports status: true, restart: true, start: true, stop: true
  action [:enable, :start]
  # provider Chef::Provider::CrowbarPacemakerService if ha_enabled
  subscribes :restart, resources(template: "/etc/monasca/agent/agent.yaml")
  subscribes :restart, resources(template: "/etc/monasca/agent/supervisor.conf")
end

##########################################################
# plugin config
##########################################################

# configure basic system plugins
["cpu", "memory", "load", "network", "disk"].each do |plugin|
  file "/etc/monasca/agent/conf.d/#{plugin}.yaml" do
    content lazy { IO.read("/usr/share/monasca/agent/conf.d/#{plugin}.yaml") }
    owner agent_settings[:user]
    group agent_settings[:group]
    mode "0640"
    notifies :restart, resources(service: agent_settings[:agent_service_name]), :delayed
  end
end
