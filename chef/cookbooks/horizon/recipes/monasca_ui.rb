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

keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)
monasca_server = node_search_with_cache("roles:monasca-server").first
monasca_master = node_search_with_cache("roles:monasca-master").first
monasca_host = MonascaUiHelper.monasca_admin_host(monasca_server)
grafana_password = monasca_master[:monasca][:master][:database_grafana_password]

# Used for creating data source
grafana_base_url = ::File.join(MonascaUiHelper.dashboard_local_url(node), "/grafana")

# Used to check whether Grafana is alive
grafana_service_url = MonascaUiHelper.grafana_service_url(node)

ha_enabled = node[:horizon][:ha][:enabled]

if monasca_server.nil?
  Chef::Log.warn("No monasca-server found.")
  return
end

if monasca_master.nil?
  Chef::Log.warn("No monasca-master found.")
  return
end

template "/srv/www/openstack-dashboard/openstack_dashboard/"\
         "local/local_settings.d/_80_monasca_ui_settings.py" do
  source "_80_monasca_ui_settings.py.erb"
  variables(
    endpoint_region: keystone_settings["endpoint_region"],
    kibana_enabled: true,
    kibana_host: MonascaUiHelper.monasca_public_host(monasca_server)
  )
  owner "root"
  group "root"
  mode "0644"
  notifies :reload, resources(service: "apache2")
end

package "grafana" do
  action :install
end

template "/etc/grafana/grafana.ini" do
  source "grafana.ini.erb"
  variables(
    database_host: monasca_host,
    grafana_password: grafana_password
  )
  owner "root"
  group "grafana"
  mode "0640"
end

service "grafana-server" do
  supports status: true, restart: true, start: true, stop: true
  action [:enable, :start]
  subscribes :restart, resources(template: "/etc/grafana/grafana.ini")
end

["monasca-grafana-datasource", "grafana-natel-discrete-panel",
 "grafana-monasca-ui-drilldown"].each do |pkg|
  package pkg do
    action :install
    notifies :restart, resources(service: "grafana-server")
  end
end

cookbook_file "/var/lib/grafana/dashboards/monasca.json" do
  source "grafana-monasca.json"
  owner "root"
  group "root"
  mode "0644"
  notifies :restart, resources(service: "grafana-server")
end

cookbook_file "/var/lib/grafana/dashboards/openstack.json" do
  source "grafana-openstack.json"
  owner "root"
  group "root"
  mode "0644"
  notifies :restart, resources(service: "grafana-server")
end

# Grafana takes a few seconds from startup until it's actually listening, so
# we'll need to wait for it:
execute "grafana listening?" do
  command "while true; do sleep 5; curl -s #{grafana_service_url} > /dev/null && break; done"
  timeout 60
  # We'll end up triggering this twice: once immediately because we also need
  # to notify the horizon_grafana_datasource if the grafana-server resource
  # hasn't changed and once if it is triggered by grafana-server. In the latter
  # case the first invocation will fail for a clean slate deployment because
  # grafana-server isn't running, yet. Hence we need to check the service's
  # status here.
  only_if { system("systemctl status grafana-server > /dev/null") }
  subscribes :run, resources(service: "grafana-server")
end

horizon_grafana_datasource "Monasca (Crowbar)" do
  action :nothing
  is_default true
  user_name "admin"
  password grafana_password
  grafana_url grafana_base_url
  proxy_url "../monitoring/proxy/"
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
  subscribes :create, resources(execute: "grafana listening?"), :immediately
end
