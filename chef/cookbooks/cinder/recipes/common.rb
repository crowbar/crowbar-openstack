# Copyright 2012 Dell, Inc.
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
# Cookbook Name:: cinder
# Recipe:: common
#

cinder_path = "/opt/cinder"

pfs_and_install_deps "cinder" do
  path cinder_path
end

create_user_and_dirs "cinder" do
  user_name node[:cinder][:user]
end

execute "cp_policy.json_#{@cookbook_name}" do
  command "cp #{cinder_path}/etc/cinder/policy.json /etc/cinder/"
  creates "/etc/cinder/policy.json"
end

template "/etc/sudoers.d/cinder-rootwrap" do
  source "cinder-rootwrap.erb"
  mode 0440
  variables(:user => node[:cinder][:user])
end

bash "deploy_filters_#{@cookbook_name}" do
  cwd cinder_path
  code <<-EOH
    ### that was copied from devstack's stack.sh
    if [[ -d $CINDER_DIR/etc/cinder/rootwrap.d ]]; then
        # Wipe any existing rootwrap.d files first
        if [[ -d $CINDER_CONF_DIR/rootwrap.d ]]; then
            rm -rf $CINDER_CONF_DIR/rootwrap.d
        fi
        # Deploy filters to /etc/cinder/rootwrap.d
        mkdir -m 755 $CINDER_CONF_DIR/rootwrap.d
        cp $CINDER_DIR/etc/cinder/rootwrap.d/*.filters $CINDER_CONF_DIR/rootwrap.d
        chown -R root:root $CINDER_CONF_DIR/rootwrap.d
        chmod 644 $CINDER_CONF_DIR/rootwrap.d/*
        # Set up rootwrap.conf, pointing to /etc/cinder/rootwrap.d
        cp $CINDER_DIR/etc/cinder/rootwrap.conf $CINDER_CONF_DIR/
        sed -e "s:^filters_path=.*$:filters_path=$CINDER_CONF_DIR/rootwrap.d:" -i $CINDER_CONF_DIR/rootwrap.conf
        chown root:root $CINDER_CONF_DIR/rootwrap.conf
        chmod 0644 $CINDER_CONF_DIR/rootwrap.conf
    fi
    ### end
  EOH
  environment({
    'CINDER_DIR' => cinder_path,
    'CINDER_CONF_DIR' => '/etc/cinder'
  })
  not_if {File.exists?("/etc/cinder/rootwrap.d")}
end

env_filter = " AND nova_config_environment:nova-config-#{node[:cinder][:nova_instance]}"

novas = search(:node, "recipes:nova\\:\\:api#{env_filter}") || []
if novas.length > 0
  nova = novas[0]
  nova = node if nova.name == node.name
else
  nova = node
end

glance_env_filter = " AND glance_config_environment:glance-config-#{nova[:nova][:glance_instance]}"
glance_servers = search(:node, "roles:glance-server#{glance_env_filter}") || []

if glance_servers.length > 0
  glance_server = glance_servers[0]
  glance_server = node if glance_server.name == node.name
  glance_server_ip = Chef::Recipe::Barclamp::Inventory.get_network_by_type(glance_server, "admin").address
  glance_server_port = glance_server[:glance][:api][:bind_port]
else
  glance_server_ip = nil
  glance_server_port = nil
end
Chef::Log.info("Glance server at #{glance_server_ip}")

mysql_env_filter = " AND mysql_config_environment:mysql-config-#{nova[:nova][:db][:mysql_instance]}"
mysqls = search(:node, "roles:mysql-server#{mysql_env_filter}")
if mysqls.length > 0
  mysql = mysqls[0]
  mysql = node if mysql.name == node.name
else
  mysql = node
end

mysql_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(mysql, "admin").address if mysql_address.nil?
Chef::Log.info("Mysql server found at #{mysql_address}")

sql_connection = "mysql://#{node[:cinder][:db][:user]}:#{node[:cinder][:db][:password]}@#{mysql_address}/#{node[:cinder][:db][:database]}"

my_ipaddress = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "admin").address
node[:glance][:api][:bind_host] = my_ipaddress

node[:nova][:my_ip] = my_ipaddress

template "/etc/cinder/cinder.conf" do
  source "cinder.conf.erb"
  owner node[:cinder][:user]
  group "root"
  mode 0640
  variables(
            :sql_connection => sql_connection,
            :rabbit_host => nova[:rabbitmq][:address],
            :rabbit_userid => nova[:nova][:rabbit][:user],
            :rabbit_password => nova[:nova][:rabbit][:password],
            :rabbit_virtual_host => nova[:nova][:rabbit][:vhost],
            :glance_server_ip => glance_server_ip,
            :glance_server_port => glance_server_port
            )
end

node.save
