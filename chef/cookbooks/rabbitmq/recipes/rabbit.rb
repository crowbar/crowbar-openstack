#
# Cookbook Name:: rabbitmq
# Recipe:: rabbit
#
# Copyright 2010, Opscode, Inc.
# Copyright 2011, Dell, Inc.
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

node.set[:rabbitmq][:address] = CrowbarRabbitmqHelper.get_listen_address(node)
node.set[:rabbitmq][:management_address] = node[:rabbitmq][:address]
addresses = [node[:rabbitmq][:address]]
if node[:rabbitmq][:listen_public]
  addresses << CrowbarRabbitmqHelper.get_public_listen_address(node)
end
node.set[:rabbitmq][:addresses] = addresses

if ha_enabled
  node.set[:rabbitmq][:nodename] = "rabbit@#{CrowbarRabbitmqHelper.get_ha_vhostname(node)}"
end

include_recipe "rabbitmq::default"

if ha_enabled
  log "HA support for rabbitmq is enabled"
  include_recipe "rabbitmq::ha"
  # All the rabbitmqctl commands are local, and can only be run if rabbitmq is
  # local
  service_name = "rabbitmq"
  only_if_command = "crm resource show #{service_name} | grep -q \" #{node.hostname} *$\""
else
  log "HA support for rabbitmq is disabled"
end

# remove guest user
rabbitmq_user "remove guest user" do
  user "guest"
  action :delete
  only_if only_if_command if ha_enabled
end

# add a vhost to the queue
rabbitmq_vhost node[:rabbitmq][:vhost] do
  action :add
  only_if only_if_command if ha_enabled
end

# create user for the queue
rabbitmq_user "adding user #{node[:rabbitmq][:user]}" do
  user node[:rabbitmq][:user]
  password node[:rabbitmq][:password]
  address node[:rabbitmq][:management_address]
  port node[:rabbitmq][:management_port]
  action :add
  only_if only_if_command if ha_enabled
end

# grant the user created above the ability to do anything with the vhost
# the three regex's map to config, write, read permissions respectively
rabbitmq_user "setting permissions for #{node[:rabbitmq][:user]}" do
  user node[:rabbitmq][:user]
  vhost node[:rabbitmq][:vhost]
  permissions "\".*\" \".*\" \".*\""
  action :set_permissions
  only_if only_if_command if ha_enabled
end

execute "rabbitmqctl set_user_tags #{node[:rabbitmq][:user]} management" do
  not_if "rabbitmqctl list_users | grep #{node[:rabbitmq][:user]} | grep -q management"
  action :run
  only_if only_if_command if ha_enabled
end

if node[:rabbitmq][:trove][:enabled]
  rabbitmq_vhost node[:rabbitmq][:trove][:vhost] do
    action :add
    only_if only_if_command if ha_enabled
  end

  rabbitmq_user "adding user #{node[:rabbitmq][:trove][:user]}" do
    user node[:rabbitmq][:trove][:user]
    password node[:rabbitmq][:trove][:password]
    address node[:rabbitmq][:management_address]
    port node[:rabbitmq][:management_port]
    action :add
    only_if only_if_command if ha_enabled
  end

  # grant the trove user the ability to do anything with the trove vhost
  # the three regex's map to config, write, read permissions respectively
  rabbitmq_user "setting permissions for #{node[:rabbitmq][:trove][:user]}" do
    user node[:rabbitmq][:trove][:user]
    vhost node[:rabbitmq][:trove][:vhost]
    permissions "\".*\" \".*\" \".*\""
    action :set_permissions
    only_if only_if_command if ha_enabled
  end
else
  rabbitmq_user "deleting user #{node[:rabbitmq][:trove][:user]}" do
    user node[:rabbitmq][:trove][:user]
    address node[:rabbitmq][:management_address]
    port node[:rabbitmq][:management_port]
    action :delete
    only_if only_if_command if ha_enabled
  end

  rabbitmq_vhost node[:rabbitmq][:trove][:vhost] do
    action :delete
    only_if only_if_command if ha_enabled
  end
end

service = "rabbitmq-server"
if node[:rabbitmq][:resource_limits] && node[:rabbitmq][:resource_limits][service]
  limits = node[:rabbitmq][:resource_limits][service]
  limit_action = limits.values.any? ? :create : :delete
  # If using HA, we manage pam_limits for rabbitmq with limits.conf, otherwise
  # we manage it through systemd
  if ha_enabled
    limits = Hash[limits.map { |k, v| [k.gsub(/^Limit/, "").downcase, v] }]
    directory "/etc/security/limits.d" do
      action :create
      owner "root"
      group "root"
      mode "0755"
    end
    template "/etc/security/limits.d/rabbitmq.conf" do
      action limit_action
      source "limits.erb"
      owner "root"
      group "root"
      mode "0644"
      variables(
        limits: limits
      )
      notifies :restart, resources(service: service)
    end
  else
    utils_systemd_override_limits "Resource limits for #{service}" do
      service_name service
      limits limits
      action limit_action
    end
  end
end

# save data so it can be found by search
node.save
