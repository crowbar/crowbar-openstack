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
if monasca_server.nil?
  Chef::Log.warn("No monasca-server found.")
  return
end
grafana_password = monasca_server[:monasca][:db_grafana][:password]
db_settings = fetch_database_settings
db_host = db_settings[:address]

# Used for creating data source
grafana_base_url = ::File.join(MonascaUiHelper.dashboard_local_url(node), "/grafana")

# Used to check whether Grafana is alive
grafana_service_url = MonascaUiHelper.grafana_service_url(node)

ha_enabled = node[:horizon][:ha][:enabled]

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

grafana_db = node[:monasca][:db_grafana]

database "create #{grafana_db[:database]} database" do
  connection db_settings[:connection]
  database_name grafana_db[:database]
  provider db_settings[:provider]
  action :create
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

database_user "create #{grafana_db[:user]} database user" do
  connection db_settings[:connection]
  username grafana_db[:user]
  password grafana_db[:password]
  provider db_settings[:user_provider]
  host "%"
  action :create
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

database_user "grant privileges to the #{grafana_db[:user]} database user" do
  connection db_settings[:connection]
  database_name grafana_db[:database]
  username grafana_db[:user]
  password grafana_db[:password]
  host "%"
  privileges db_settings[:privs]
  provider db_settings[:user_provider]
  require_ssl db_settings[:connection][:ssl][:enabled]
  action :grant
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

# When upgrading from Cloud 8, restore the Monasca database dumped from the
# Monasca node and stamp it with Alembic revision information. We stop
# grafana-server as part of this to make sure there's no concurrent write
# access to the DB.
if node["crowbar_upgrade_step"] == "done_os_upgrade"
  service "stop grafana-server for DB restore" do
    service_name "grafana-server"
    supports status: true, restart: true, start: true, stop: true
    action [:disable, :stop]
    not_if { File.exist?("/var/lib/crowbar/upgrade/grafana_db_restored") }
  end

  execute "restore Grafana DB" do
    command  " /usr/bin/zcat /var/lib/crowbar/upgrade/monasca-grafana-database.dump.gz"\
             " | /usr/bin/mysql"\
             "     -h #{db_host}"\
             "     -u #{grafana_db[:user]}"\
             "   \"-p#{grafana_db[:password]}\""\
             " #{grafana_db[:database]}"\
             " && touch /var/lib/crowbar/upgrade/grafana_db_restored"
    subscribes :run, resources(service: "stop grafana-server for DB restore"), :immediately
    action :run
    not_if { File.exist?("/var/lib/crowbar/upgrade/grafana_db_restored") }
    only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end
end

template "/etc/grafana/grafana.ini" do
  source "grafana.ini.erb"
  variables(
    database_host: db_settings[:address],
    grafana_password: grafana_password
  )
  owner "root"
  group "grafana"
  mode "0640"
end

crowbar_pacemaker_sync_mark "wait-grafana_migrations" do
  timeout 120
  only_if { ha_enabled }
end

# Start Grafana server on cluster founder first to ensure database migrations
# happen there...

service "grafana-server" do
  supports status: true, restart: true, start: true, stop: true
  action [:enable, :start]
  subscribes :restart, resources(template: "/etc/grafana/grafana.ini")
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

crowbar_pacemaker_sync_mark "create-grafana_migrations" if ha_enabled

# ...then start Grafana server on all other nodes.

service "grafana-server" do
  supports status: true, restart: true, start: true, stop: true
  action [:enable, :start]
  subscribes :restart, resources(template: "/etc/grafana/grafana.ini")
  only_if { ha_enabled && !CrowbarPacemakerHelper.is_cluster_founder?(node) }
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
  group "grafana"
  mode "0640"
  notifies :restart, resources(service: "grafana-server")
end

template "/var/lib/grafana/dashboards/openstack.json" do
  source "grafana-openstack.json.erb"
  variables(
    ceph_enabled: monasca_server[:monasca][:agent][:monitor_ceph]
  )
  owner "root"
  group "grafana"
  mode "0640"
  notifies :restart, resources(service: "grafana-server")
end

cookbook_file "/etc/grafana/provisioning/dashboards/default.yaml" do
  source "default-dashboards-provider.yaml"
  owner "root"
  group "grafana"
  mode "0640"
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
