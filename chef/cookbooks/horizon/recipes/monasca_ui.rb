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

monasca_server = node_search_with_cache("roles:monasca-server").first
if monasca_server.nil?
  Chef::Log.warn("No monasca-server found.")
  return
end

template "/srv/www/openstack-dashboard/openstack_dashboard/"\
         "local/local_settings.d/_80_monasca_ui_settings.py" do
  source "_80_monasca_ui_settings.py.erb"
  variables(
    kibana_enabled: true,
    kibana_host: MonascaUiHelper.monasca_public_host(monasca_server)
  )
  owner "root"
  group "root"
  mode "0644"
  notifies :reload, resources(service: "apache2")
end

package "grafana-apache" do
  action :install
  notifies :reload, resources(service: "apache2")
end

template "/srv/www/grafana/config.js" do
  source "grafana-config.js"
  variables(
    api_url: MonascaUiHelper.api_public_url(monasca_server)
  )
  owner "root"
  group "www"
  mode "0644"
  notifies :reload, resources(service: "apache2")
end

cookbook_file "/srv/www/grafana/app/dashboards/openstack.json" do
  source "grafana-openstack.json"
  owner "root"
  group "root"
  mode "0644"
  notifies :reload, resources(service: "apache2")
end

cookbook_file "/srv/www/grafana/app/dashboards/monasca.json" do
  source "grafana-monasca.json"
  owner "root"
  group "root"
  mode "0644"
  notifies :reload, resources(service: "apache2")
end
