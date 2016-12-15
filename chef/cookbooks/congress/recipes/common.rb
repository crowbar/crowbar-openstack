# Copyright 2015 SUSE Linux GmbH
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

# package "openstack-congress"

db_settings = fetch_database_settings

include_recipe "database::client"
include_recipe "#{db_settings[:backend_name]}::client"
include_recipe "#{db_settings[:backend_name]}::python-client"

# get Database data
db_password = ""
if node.roles.include? "congress-server"
  db_password = node[:congress][:db][:password]
else
  # pickup password to database from congress-server node
  node_servers = search(:node, "roles:congress-server") || []
  if node_servers.length > 0
    db_password = node_servers[0][:congress][:db][:password]
  end
end
sql_connection = "#{db_settings[:url_scheme]}://#{node[:congress][:db][:user]}:"\
                 "#{db_password}@#{db_settings[:address]}/"\
                 "#{node[:congress][:db][:database]}"

# address/port binding
my_ipaddress = Chef::Recipe::Barclamp::Inventory.get_network_by_type(
  node, "admin").address
node[:congress][:my_ip] = my_ipaddress
node[:congress][:api][:bind_host] = my_ipaddress

if node[:congress][:ha][:enabled]
  bind_port = node[:congress][:ha][:ports][:api]
else
  if node[:congress][:api][:bind_open_address]
    bind_host = "0.0.0.0"
  else
    bind_host = node[:congress][:api][:bind_host]
  end
  bind_port = node[:congress][:api][:bind_port]
end


# get Neutron data (copied from nova.conf.erb)
# TODO(toabctl): Seems that this code is used in different barclamps.
# Should be shared
neutron_servers = search(:node, "roles:neutron-server") || []
if neutron_servers.length > 0
  neutron_server = neutron_servers[0]
  neutron_server = node if neutron_server.name == node.name
  neutron_protocol = neutron_server[:neutron][:api][:protocol]
  neutron_server_host = CrowbarHelper.get_host_for_admin_url(
    neutron_server,
    (neutron_server[:neutron][:ha][:server][:enabled] || false))
  neutron_server_port = neutron_server[:neutron][:api][:service_port]
  neutron_insecure = neutron_protocol == "https" &&
                     neutron_server[:neutron][:ssl][:insecure]
  neutron_service_user = neutron_server[:neutron][:service_user]
  neutron_service_password = neutron_server[:neutron][:service_password]
  Chef::Log.info("Neutron server at #{neutron_server_host}")
else
  neutron_insecure = nil
  neutron_protocol = nil
  neutron_server_host = nil
  neutron_server_port = nil
  neutron_service_user = nil
  neutron_service_password = nil
  Chef::Log.warn("Neutron server not found")
end

# get Nova data
nova = search(:node, "roles:nova-controller") || []
if nova.length > 0
  nova = nova[0]
  nova_insecure = (
      nova[:nova][:ssl][:enabled] && nova[:nova][:ssl][:insecure]
  )
  nova_admin_username = nova[:nova][:service_user]
  nova_admin_password = nova[:nova][:service_password]
else
  nova_insecure = nil
  nova_admin_username = nil
  nova_admin_password = nil
  Chef::Log.warn("nova-controller not found")
end

# get Cinder data
cinder = search(:node, "roles:cinder-controller") || []
if cinder.length > 0
  cinder = cinder[0]
  cinder_insecure = (
    cinder[:cinder][:ssl][:enabled] && cinder[:cinder][:ssl][:insecure]
  )

  cinder_admin_username = cinder[:cinder][:service_user]
  cinder_admin_password = cinder[:cinder][:service_password]
else
  cinder_insecure = nil
  cinder_admin_username = nil
  cinder_admin_password = nil
  Chef::Log.warn("cinder-controller not found")
end

template "/etc/congress/congress.conf" do
  source "congress.conf.erb"
  owner "root"
  group node[:congress][:group]
  mode 0640
  variables(
    bind_host: bind_host,
    bind_port: bind_port,
    sql_connection: sql_connection,
    rabbit_settings: fetch_rabbitmq_settings,
    keystone_settings: KeystoneHelper.keystone_settings(node, :congress),
    neutron_insecure: neutron_insecure,
    neutron_protocol: neutron_protocol,
    neutron_server_host: neutron_server_host,
    neutron_server_port: neutron_server_port,
    neutron_service_user: neutron_service_user,
    neutron_service_password: neutron_service_password,
    nova_insecure: nova_insecure,
    nova_admin_username: nova_admin_username,
    nova_admin_password: nova_admin_password,
    cinder_insecure: cinder_insecure,
    cinder_admin_username: cinder_admin_username,
    cinder_admin_password: cinder_admin_password
  )
end

node.save
