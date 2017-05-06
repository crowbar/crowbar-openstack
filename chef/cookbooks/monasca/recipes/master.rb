#
# Copyright 2017 Fujitsu LIMITED
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
# limitation.
#

monasca_servers = search(:node, "roles:monasca-server")
monasca_hosts = MonascaHelper.monasca_hosts(monasca_servers)
raise "no nodes with monasca-server role found" if monasca_hosts.nil? || monasca_hosts.empty?

package "ansible"
package "monasca-installer"

cookbook_file "/etc/ansible/ansible.cfg" do
  source "ansible.cfg"
  owner "root"
  group "root"
  mode "0644"
end

keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)

hosts_template =
  if monasca_hosts.length == 1
    "monasca-hosts-single.erb"
  else
    "monasca-hosts-cluster.erb"
  end

template "/opt/monasca-installer/monasca-hosts" do
  source hosts_template
  owner "root"
  group "root"
  mode "0644"
  variables(
    monasca_hosts: monasca_hosts,
    ansible_ssh_user: "root",
    keystone_host: keystone_settings["public_url_host"]
  )
  notifies :run, "execute[run ansible]", :delayed
end

# This file is used to mark that ansible installer run successfully.
# Without this, it could happen that the installer was not re-tried
# after a failed run.
file "/opt/monasca-installer/.installed" do
  content "monasca installed"
  owner "root"
  group "root"
  mode "0644"
  notifies :run, "execute[run ansible]", :delayed
  action :create_if_missing
end

monasca_node = monasca_servers[0]
monasca_net_ip = MonascaHelper.get_host_for_monitoring_url(monasca_node)
pub_net_ip = CrowbarHelper.get_host_for_public_url(monasca_node, false, false)

ansible_vars = {
  influxdb_mon_api_password: node[:monasca][:master][:influxdb_mon_api_password],
  influxdb_mon_persister_password: node[:monasca][:master][:influxdb_mon_persister_password],
  database_notification_password: node[:monasca][:master][:database_notification_password],
  database_monapi_password: node[:monasca][:master][:database_monapi_password],
  database_thresh_password: node[:monasca][:master][:database_thresh_password],
  database_logapi_password: node[:monasca][:master][:database_logapi_password],
  keystone_monasca_operator_password:
    node[:monasca][:master][:keystone_monasca_operator_password],
  keystone_monasca_agent_password: node[:monasca][:master][:keystone_monasca_agent_password],
  keystone_admin_agent_password: node[:monasca][:master][:keystone_admin_agent_password],
  keystone_admin_password: keystone_settings["admin_password"],
  api_region: keystone_settings["endpoint_region"],
  database_grafana_password: node[:monasca][:master][:database_grafana_password],

  notification_enable_email: node[:monasca][:master][:notification_enable_email],
  smtp_host: node[:monasca][:master][:smtp_host],
  smtp_port: node[:monasca][:master][:smtp_port],
  smtp_user: node[:monasca][:master][:smtp_user],
  smtp_password: node[:monasca][:master][:smtp_password],
  smtp_from_address: node[:monasca][:master][:smtp_from_address],

  keystone_version: keystone_settings["api_version"],
  keystone_url: keystone_settings["public_auth_url"],
  keystone_admin_token: keystone_settings["admin_token"],
  keystone_admin: keystone_settings["admin_user"],
  keystone_admin_project: keystone_settings["admin_tenant"],

  memcached_listen_ip: monasca_net_ip,
  kafka_host: monasca_net_ip,
  kibana_host: pub_net_ip,
  kibana_plugins: {
    "monasca-kibana-plugin" => {
      "url" => "file:///usr/share/monasca-kibana-plugin/monasca-kibana-plugin.tar.gz",
      "configuration" => {
        "monasca-kibana-plugin.enabled" => true,
        "monasca-kibana-plugin.auth_uri" => keystone_settings["public_auth_url"],
        "monasca-kibana-plugin.cookie.isSecure" => false
      }
    }
  },
  log_api_bind_host: "*",
  influxdb_bind_address: monasca_net_ip,
  influxdb_host: monasca_net_ip,
  monasca_api_bind_host: "*",
  elasticsearch_host: monasca_net_ip,
  nimbus_host: monasca_net_ip,
  zookeeper_hosts: monasca_net_ip,
  kafka_hosts: "#{monasca_net_ip}:9092",
  mariadb_bind_address: monasca_net_ip,
  database_host: monasca_net_ip,
  monasca_api_url: "http://#{pub_net_ip}:#{node[:monasca][:api][:bind_port]}/v2.0",
  monasca_log_api_url: "http://#{pub_net_ip}:#{node[:monasca][:log_api][:bind_port]}/v2.0",
  memcached_nodes: ["#{monasca_net_ip}:11211"],
  influxdb_url: "http://#{monasca_net_ip}:8086",
  elasticsearch_nodes: "[#{monasca_net_ip}]",
  elasticsearch_hosts: monasca_net_ip,
  monasca_api_log_level: node[:monasca][:api][:log_level],
  log_api_log_level: node[:monasca][:log_api][:log_level]
}.to_json

execute "run ansible" do
  command "rm -f /opt/monasca-installer/.installed " \
          "&& ansible-playbook -i monasca-hosts -e '#{ansible_vars}' monasca.yml " \
          "&& touch /opt/monasca-installer/.installed"
  cwd "/opt/monasca-installer"
  action :nothing
end
