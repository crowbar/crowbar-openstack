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
quorum = CrowbarPacemakerHelper.num_corosync_nodes(node) / 2 + 1
crm_resource_stop_cmd = cluster_enabled ? "force-demote" : "force-stop"
crm_resource_start_cmd = cluster_enabled ? "force-promote" : "force-start"

cluster_partition_handling = if cluster_enabled
  if CrowbarPacemakerHelper.num_corosync_nodes(node) > 2
    "pause_minority"
  else
    "ignore"
  end
else
  "unused"
end

package "rabbitmq-server"
package "rabbitmq-server-plugins" if node[:platform_family] == "suse"

if node[:platform_family] == "suse"
  # With new erlang packages, we move to a system-wide epmd service, with a
  # epmd.socket unit. This is enabled by default but only listens on 127.0.0.1,
  # while we need it to listen on the admin network too.

  directory "/etc/systemd/system/epmd.socket.d" do
    owner "root"
    group "root"
    mode 0o755
    action :create
    only_if "systemctl list-dependencies --plain rabbitmq-server.service | grep -q epmd.service"
  end

  template "/etc/systemd/system/epmd.socket.d/port.conf" do
    source "epmd.socket-port.conf.erb"
    owner "root"
    group "root"
    mode 0o644
    variables(
      listen_address: node[:rabbitmq][:address]
    )
    only_if "systemctl list-dependencies --plain rabbitmq-server.service | grep -q epmd.service"
  end

  bash "reload systemd for epmd.socket extension" do
    code "systemctl daemon-reload"
    action :nothing
    subscribes :run, "template[/etc/systemd/system/epmd.socket.d/port.conf]", :immediate
  end

  # Enable epmd.socket for two reasons:
  # 1. when we don't use the rabbitmq systemd service (in HA, for instance),
  #    this will enable the use of the system-wide epmd
  # 2. the call to rabbitmq-plugins before we start the rabbitmq-server service
  #    will cause epmd to be started, but not by systemd; this will make the
  #    rabbitmq-server service fail to start due to dependencies. By
  #    proactively starting epmd.socket, we avoid this.
  # (not a typo, we want the socket, not the service here)
  service "epmd.socket" do
    action [:enable, :start]
    only_if "systemctl list-dependencies --plain rabbitmq-server.service | grep -q epmd.service"
    subscribes :restart, "template[/etc/systemd/system/epmd.socket.d/port.conf]", :immediate
  end
end

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
  notifies :restart, "service[rabbitmq-server]"
end

`systemd-detect-virt -v -q`
virtualized = $?.exitstatus.zero?
hipe_compile = node[:rabbitmq][:hipe_compile] && !virtualized

template "/etc/rabbitmq/rabbitmq.config" do
  source "rabbitmq.config.erb"
  owner "root"
  group "root"
  mode 0644
  variables(
    cluster_enabled: cluster_enabled,
    cluster_partition_handling: cluster_partition_handling,
    hipe_compile: hipe_compile
  )
  notifies :restart, "service[rabbitmq-server]"
end

# create a file with definitions to load on start, to be 100% sure we always
# start with a usable state
template "/etc/rabbitmq/definitions.json" do
  source "definitions.json.erb"
  owner "root"
  group node[:rabbitmq][:rabbitmq_group]
  mode 0o640
  variables(
    json_user: node[:rabbitmq][:user].to_json,
    # ideally we'd put a hash in the file, but the hash would change on each
    # chef run and we don't want to rewrite the file all the time
    json_password: node[:rabbitmq][:password].to_json,
    json_vhost: node[:rabbitmq][:vhost].to_json,
    trove_enabled: node[:rabbitmq][:trove][:enabled],
    json_trove_user: node[:rabbitmq][:trove][:user].to_json,
    json_trove_password: node[:rabbitmq][:trove][:password].to_json,
    json_trove_vhost: node[:rabbitmq][:trove][:vhost].to_json,
    ha_all_policy: cluster_enabled,
    quorum: quorum,
    extra_users: node[:rabbitmq][:users]
  )
  # no notification to restart rabbitmq, as we still do changes with
  # rabbitmqctl in the rabbit.rb recipe (this is less disruptive)
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
  notifies :restart, "service[rabbitmq-server]"
end

service "rabbitmq-server" do
  supports restart: true,
           start: true,
           stop: true,
           status: true,
           crm_resource_stop_cmd: crm_resource_stop_cmd,
           crm_resource_start_cmd: crm_resource_start_cmd
  action [:enable, :start]
  provider Chef::Provider::CrowbarPacemakerService if ha_enabled
end
utils_systemd_service_restart "rabbitmq-server" do
  action ha_enabled ? :disable : :enable
end
