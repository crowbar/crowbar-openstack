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
# we only do cluster if we do HA
cluster_enabled = node[:rabbitmq][:cluster] && ha_enabled

dirty = false

management_address = CrowbarRabbitmqHelper.get_management_address(node)
nodename = "rabbit@#{CrowbarRabbitmqHelper.get_ha_vhostname(node)}"

if cluster_enabled
  if node[:rabbitmq][:nodename] != "rabbit@#{node[:hostname]}"
    node.set[:rabbitmq][:nodename] = "rabbit@#{node[:hostname]}"
    dirty = true
  end
  if node[:rabbitmq][:clustername] != nodename
    node.set[:rabbitmq][:clustername] = nodename
    dirty = true
  end
elsif ha_enabled
  if node[:rabbitmq][:nodename] != nodename
    node.set[:rabbitmq][:nodename] = nodename
    dirty = true
  end
end

node.save if dirty

include_recipe "rabbitmq::default"

if node[:rabbitmq][:ssl][:enabled]
  ssl_setup "setting up ssl for rabbitmq" do
    generate_certs node[:rabbitmq][:ssl][:generate_certs]
    certfile node[:rabbitmq][:ssl][:certfile]
    keyfile node[:rabbitmq][:ssl][:keyfile]
    group "rabbitmq"
    fqdn node[:fqdn]
    cert_required node[:rabbitmq][:ssl][:cert_required]
    ca_certs node[:rabbitmq][:ssl][:ca_certs]
  end
end

if ha_enabled
  log "HA support for rabbitmq is enabled"
  if cluster_enabled
    include_recipe "rabbitmq::ha_cluster"
    # only run the rabbitmqctl commands on the master node
    ms_name = "ms-rabbitmq"
    only_if_command = "crm resource show #{ms_name} | grep -q \" #{node.hostname} *Master$\""
  else
    include_recipe "rabbitmq::ha"
    # All the rabbitmqctl commands are local, and can only be run if rabbitmq is
    # local
    service_name = "rabbitmq"
    only_if_command = "crm resource show #{service_name} | grep -q \" #{node.hostname} *$\""
  end
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
  address management_address
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

node[:rabbitmq][:users].each do |user|
  # create extra users
  rabbitmq_user "adding user #{user[:username]}" do
    user user[:username]
    password user[:password]
    address management_address
    port node[:rabbitmq][:management_port]
    action :add
    only_if only_if_command if ha_enabled
  end

  # add permisions to those extra users into the default vhost
  rabbitmq_user "setting permissions for #{user[:username]}" do
    user user[:username]
    vhost node[:rabbitmq][:vhost]
    # permissions is a list but the resource needs an escaped string
    permissions user[:permissions].map { |x| "'#{x}'" }.join(" ")
    action :set_permissions
    only_if only_if_command if ha_enabled
  end

  # tag those users as management
  execute "rabbitmqctl set_user_tags #{user[:username]} #{user[:tags].join(",")}" do
    not_if "rabbitmqctl list_users | grep #{user[:username]} | grep -q #{user[:tags].join(",")}"
    action :run
    only_if only_if_command if ha_enabled
  end
end

if cluster_enabled
  if node[:rabbitmq][:enable_queue_mirroring]
    quorum = CrowbarPacemakerHelper.num_corosync_nodes(node) / 2 + 1
  else
    quorum = 1
  end

  # don't mirror queues that are 'amqp.*' or '*_fanout_*' or `reply_*` in their names
  queue_regex = "^(?!(amqp.)|(.*_fanout_)|(reply_)).*"
  # policy doesnt need spaces between elements as they will be removed when listing them
  # making it more difficult to check for them
  policy = "{\"ha-mode\":\"exactly\",\"ha-params\":#{quorum},\"ha-sync-mode\":\"automatic\"}"
  vhost = node[:rabbitmq][:vhost]
  # we need to scape the regex properly so we can use it on the grep command
  queue_regex_escaped = ""
  queue_regex.split("").each { |c| queue_regex_escaped << "\\" + c }

  set_policy_command = "rabbitmqctl set_policy -p #{vhost} --apply-to queues " \
      " ha-queues '#{queue_regex}' '#{policy}'"
  check_policy_command = "rabbitmqctl list_policies -p #{vhost} | " \
      " grep -Eq '^#{vhost}\\s*ha-queues\\s*queues\\s*#{queue_regex_escaped}\\s*#{policy}\\s*0$'"

  execute set_policy_command do
    not_if check_policy_command
    action :run
    only_if only_if_command if ha_enabled
  end

  check_cluster_name_command = "rabbitmqctl cluster_status | " \
      "grep -q '{cluster_name,<<\"#{node[:rabbitmq][:clustername]}\">>}'"
  execute "rabbitmqctl set_cluster_name #{node[:rabbitmq][:clustername]}" do
    not_if check_cluster_name_command
    action :run
    only_if only_if_command if ha_enabled
  end
end

if node[:rabbitmq][:trove][:enabled]
  rabbitmq_vhost node[:rabbitmq][:trove][:vhost] do
    action :add
    only_if only_if_command if ha_enabled
  end

  rabbitmq_user "adding user #{node[:rabbitmq][:trove][:user]}" do
    user node[:rabbitmq][:trove][:user]
    password node[:rabbitmq][:trove][:password]
    address management_address
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
    address management_address
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
