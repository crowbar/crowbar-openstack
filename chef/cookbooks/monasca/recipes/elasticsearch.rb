#
# Cookbook Name:: monasca
# Recipe:: elasticsearch
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

package "elasticsearch"

monasca_servers = search(:node, "roles:monasca-server")
monasca_hosts = MonascaHelper.monasca_hosts(monasca_servers).sort!
monasca_net_ip = MonascaHelper.get_host_for_monitoring_url(monasca_servers[0])

service "systemd-sysctl" do
  supports status: true, restart: true, start: true
end

execute "systemctl daemon-reload" do
  action :nothing
end

# NOTE: The file name must match the sysctl conf file provided
# by the elasticsearch package (this is /usr/lib/sysctl.d/elasticsearch.conf)
# From "man sysctl.d": Files in /etc/ override files with the same name
# in /run/ and /usr/lib/.
template "/etc/sysctl.d/elasticsearch.conf" do
  source "elasticsearch-sysctl-server.conf.erb"
  mode "0640"
  variables(
    elasticsearch_vm_max_map_count: node[:monasca][:elasticsearch][:tunables][:vm_max_map_count]
  )
  notifies :restart, "service[systemd-sysctl]"
end

directory "/etc/systemd/system/elasticsearch.service.d" do
  mode "0755"
end

template "/etc/systemd/system/elasticsearch.service.d/override.conf" do
  source "elasticsearch-systemd-override.conf.erb"
  mode "0644"
  variables(
    elasticsearch_limit_nproc: node[:monasca][:elasticsearch][:tunables][:limit_nproc],
    elasticsearch_limit_nofile: node[:monasca][:elasticsearch][:tunables][:limit_nofile],
    elasticsearch_limit_memlock: node[:monasca][:elasticsearch][:tunables][:limit_memlock]
  )
  notifies :run, "execute[systemctl daemon-reload]", :immediately
  notifies :restart, "service[elasticsearch]"
end

node[:monasca][:elasticsearch][:data_dirs].each do |d|
  directory d do
    mode "0755"
    owner "elasticsearch"
    group "elasticsearch"
    recursive true
  end
end

node[:monasca][:elasticsearch][:repo_dirs].each do |d|
  directory d do
    mode "0755"
    owner "elasticsearch"
    group "elasticsearch"
    recursive true
  end
end

directory node[:monasca][:elasticsearch][:log_dir] do
  mode "0755"
  owner "elasticsearch"
  group "elasticsearch"
  recursive true
end

template "/etc/elasticsearch/elasticsearch.yml" do
  source "elasticsearch.yml.erb"
  owner "elasticsearch"
  group "elasticsearch"
  mode "0640"
  variables(
    elasticsearch_cluster_name: node[:monasca][:elasticsearch][:cluster_name],
    elasticsearch_node_name: monasca_hosts[0],
    elasticsearch_is_master_node: node[:monasca][:elasticsearch][:is_master_node],
    elasticsearch_is_data_node: node[:monasca][:elasticsearch][:is_data_node],
    elasticsearch_data_dirs: node[:monasca][:elasticsearch][:data_dirs],
    elasticsearch_log_dir: node[:monasca][:elasticsearch][:log_dir],
    elasticsearch_repo_dirs: node[:monasca][:elasticsearch][:repo_dirs],
    elasticsearch_bootstrap_memory_lock: node[:monasca][:elasticsearch][:bootstrap_memory_lock],
    elasticsearch_bind_host: monasca_net_ip,
    elasticsearch_public_host: monasca_net_ip
  )
  notifies :restart, "service[elasticsearch]"
end

service "elasticsearch" do
  supports status: true, restart: true, start: true, stop: true
  action [:enable, :start]
end

# upload the logstash template to elasticsearch
package "curl"

cookbook_file "/etc/elasticsearch/monasca-logstash-template.json" do
  source "elasticsearch-monasca-logstash-template.json"
  owner "elasticsearch"
  group "elasticsearch"
  mode "0755"
end

execute "upload monasca-logstash template to elasticsearch" do
  command "/usr/bin/curl --retry 10 --retry-connrefused -XPUT 'http://#{monasca_net_ip}:9200/_template/logstash' -d @monasca-logstash-template.json"
  cwd "/etc/elasticsearch/"
  not_if "curl --retry 10 --retry-connrefused --fail -I 'http://#{monasca_net_ip}:9200/_template/logstash'"
end
