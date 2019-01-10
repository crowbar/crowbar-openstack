#
# Cookbook Name:: monasca
# Recipe:: elasticsearch-curator
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

package "python-elasticsearch-curator"

monasca_servers = search(:node, "roles:monasca-server")
monasca_hosts = MonascaHelper.monasca_hosts(monasca_servers).sort!

user "curator" do
  system true
  manage_home false
end

group "curator" do
  system true
end

group 'curator' do
  action :modify
  members 'curator'
  append true
end

directory "/var/log/elasticsearch-curator" do
  mode "0755"
  owner "curator"
  group "curator"
end

directory "/etc/elasticsearch-curator" do
  mode "0755"
  owner "curator"
  group "curator"
end

template "/etc/elasticsearch-curator/curator_config.yml" do
  source "elasticsearch-curator-config.yml.erb"
  mode "0640"
  owner "curator"
  group "curator"
  variables(
    elasticsearch_hosts: monasca_hosts,
    elasticsearch_curator_log_level: node[:monasca][:debug] ? 'DEBUG' : 'INFO'
  )
end


# curator actions
curator_actions = []
if node[:monasca][:elasticsearch_curator].key?(:delete_after_days)
  curator_actions.push(
    "delete_by" => "age",
    "description" => "Delete indices older than " \
                     "#{node[:monasca][:elasticsearch_curator][:delete_after_days]} days",
    "deleted_days" => node[:monasca][:elasticsearch_curator][:delete_after_days],
    "disable" => false
  )
end

if node[:monasca][:elasticsearch_curator].key?(:delete_after_size)
  curator_actions.push(
    "delete_by" => "size",
    "description" => "Delete indices larger than " \
                     "#{node[:monasca][:elasticsearch_curator][:delete_after_size]}MB",
    "deleted_size" => node[:monasca][:elasticsearch_curator][:delete_after_size].to_f/1000,
    "disable" => false
  )
end

curator_excluded_index = []
node[:monasca][:elasticsearch_curator][:delete_exclude_index].each do |index|
  curator_excluded_index.push(
    "index_name" => index,
    "exclude" => true
  )
end

template "/etc/elasticsearch-curator/curator_action.yml" do
  source "elasticsearch-curator-action.yml.erb"
  mode "0640"
  owner "curator"
  group "curator"
  variables(
    elasticsearch_curator_actions: curator_actions,
    elasticsearch_curator_excluded_index: curator_excluded_index
  )
end

execute "systemctl daemon-reload" do
  action :nothing
end

# cron/timer for the curator setup
template "/etc/systemd/system/elasticsearch-curator.timer" do
  source "elasticsearch-curator-systemd.timer.erb"
  mode "0644"
  notifies :run, "execute[systemctl daemon-reload]", :immediately
end

template "/etc/systemd/system/elasticsearch-curator.service" do
  source "elasticsearch-curator-systemd.service.erb"
  mode "0644"
  notifies :run, "execute[systemctl daemon-reload]", :immediately
end

service "elasticsearch-curator.timer" do
  action [:enable, :start]
end
