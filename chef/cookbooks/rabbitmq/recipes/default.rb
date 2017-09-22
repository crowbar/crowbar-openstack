#
# Cookbook Name:: rabbitmq
# Recipe:: default
#
# Copyright 2009, Benjamin Black
# Copyright 2009-2011, Opscode, Inc.
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

ha_enabled = node[:rabbitmq][:ha][:enabled]
# we only do cluster if we do HA
cluster_enabled = node[:rabbitmq][:cluster] && ha_enabled
# dont let the changes to the templates restart the rabbitmq in cluster mode
service_action = cluster_enabled ? :nothing : :restart

package "rabbitmq-server"
package "rabbitmq-server-plugins" if node[:platform_family] == "suse"

directory "/etc/rabbitmq/" do
  owner "root"
  group "root"
  mode 0755
  action :create
end

template "/etc/rabbitmq/rabbitmq-env.conf" do
  source "rabbitmq-env.conf.erb"
  owner "root"
  group "root"
  mode 0644
  notifies service_action, "service[rabbitmq-server]"
end

template "/etc/rabbitmq/rabbitmq.config" do
  source "rabbitmq.config.erb"
  owner "root"
  group "root"
  mode 0644
  notifies service_action, "service[rabbitmq-server]"
end

case node[:platform_family]
when "suse"
  rabbitmq_plugins = "/usr/sbin/rabbitmq-plugins"
  rabbitmq_plugins_param = "--offline"
when "rhel"
  rabbitmq_plugins = "/usr/lib/rabbitmq/bin/rabbitmq-plugins"
  rabbitmq_plugins_param = "--offline"
else
  rabbitmq_plugins = "#{RbConfig::CONFIG["libdir"]}/rabbitmq/bin/rabbitmq-plugins"
  rabbitmq_plugins_param = ""
end

bash "enabling rabbit management" do
  environment "HOME" => "/root/"
  code "#{rabbitmq_plugins} #{rabbitmq_plugins_param} enable rabbitmq_management > /dev/null"
  not_if "#{rabbitmq_plugins} list -E | grep rabbitmq_management -q", environment: {"HOME" => "/root/"}
  notifies service_action, "service[rabbitmq-server]"
end

service "rabbitmq-server" do
  supports restart: true, start: true, stop: true, status: true
  action [:enable, :start]
  provider Chef::Provider::CrowbarPacemakerService if ha_enabled
end
utils_systemd_service_restart "rabbitmq-server" do
  action ha_enabled ? :disable : :enable
end
