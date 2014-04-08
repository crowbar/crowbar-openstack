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

node[:rabbitmq][:address] = CrowbarRabbitmqHelper.get_listen_address(node)
if ha_enabled
  node[:rabbitmq][:nodename] = "rabbit@#{CrowbarRabbitmqHelper.get_ha_vhostname(node)}"
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

# add a vhost to the queue
rabbitmq_vhost node[:rabbitmq][:vhost] do
  action :add
  only_if only_if_command if ha_enabled
end

# create user for the queue
rabbitmq_user "adding user #{node[:rabbitmq][:user]}" do
  user node[:rabbitmq][:user]
  password node[:rabbitmq][:password]
  address node[:rabbitmq][:address]
  port node[:rabbitmq][:mochiweb_port]
  action :add
  only_if only_if_command if ha_enabled
end

# grant the mapper user the ability to do anything with the vhost
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

# save data so it can be found by search
node.save
