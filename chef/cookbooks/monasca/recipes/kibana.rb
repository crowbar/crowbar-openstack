#
# Cookbook Name:: monasca
# Recipe:: kibana
#
# Copyright 2018, SUSE Linux GmbH.
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

package "kibana"
package "monasca-kibana-plugin"

monasca_servers = search(:node, "roles:monasca-server")
monasca_host = MonascaHelper.monasca_hosts(monasca_servers)[0]

keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)

# FIXME: This doesn't work if the monasca-kibana-plugin gets an update
# but that problem already exists in the monasca-installer
execute "monasca-kibana-plugin installation" do
  command "/opt/kibana/bin/kibana plugin --install monasca-kibana-plugin --url file:///usr/share/monasca-kibana-plugin/monasca-kibana-plugin.tar.gz"
  notifies :run, "execute[kibana-optimized-permissions]"
  notifies :run, "execute[kibana-logfile-permissions]"
  notifies :restart, "service[kibana]"
  not_if { ::Dir.exists?("/opt/kibana/installedPlugins/monasca-kibana-plugin") }
end

# see https://www.elastic.co/guide/en/kibana/current/install-plugin.html
execute "kibana-optimized-permissions" do
  command "/usr/bin/chown kibana:kibana -R /opt/kibana/optimize"
  subscribes :run, "execute[monasca-kibana-plugin installation]"
  only_if "ls -lR /opt/kibana/optimize/ | grep -q root"
end

execute "kibana-logfile-permissions" do
  command "/usr/bin/chown kibana:kibana /var/log/kibana/kibana.log"
  subscribes :run, "execute[monasca-kibana-plugin installation]"
  only_if "ls -l /var/log/kibana/kibana.log | grep -q root"
end

template "/opt/kibana/config/kibana.yml" do
  source "kibana.yml.erb"
  mode "0640"
  variables(
    elasticsearch_host: monasca_host,
    monasca_kibana_plugin_auth_uri: keystone_settings["unversioned_internal_auth_url"]
  )
  notifies :restart, "service[kibana]"
end

service "kibana" do
  supports status: true, restart: true, start: true, stop: true
  action [:enable, :start]
  subscribes :restart, "execute[monasca-kibana-plugin installation]"
  subscribes :restart, "execute[kibana-optimized-permissions]"
  subscribes :restart, "execute[kibana-logfile-permissions]"
end

# Make sure Kibana gets restarted after the update to Kibana 4.6.6. This is required
# for this update only, since after the update in question, the faulty restart
# logic in the package spec's %postun section will no longer be causing trouble
# (bsc#1044849).
service "restart kibana if needed" do
  service_name "kibana"
  action [:restart]
  only_if "rpm -qa | grep -q 'kibana-4\.6\.6' && zypper ps -s | grep -q kibana"
end
