#
# Copyright 2016 SUSE Linux GmbH
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

package "openstack-magnum"

db_settings = fetch_database_settings
network_settings = MagnumHelper.network_settings(node)

ha_enabled = node[:magnum][:ha][:enabled]

memcached_servers = MemcachedHelper.get_memcached_servers(
  ha_enabled ? CrowbarPacemakerHelper.cluster_nodes(node, "magnum-server") : [node]
)
memcached_instance("magnum-server")

include_recipe "database::client"
include_recipe "#{db_settings[:backend_name]}::client"
include_recipe "#{db_settings[:backend_name]}::python-client"

# get Database data
sql_connection = fetch_database_connection_string(node[:magnum][:db])

# address/port binding
my_ipaddress = Barclamp::Inventory.get_network_by_type(node, "admin").address
if node[:magnum][:api][:bind_host] != my_ipaddress
  node.set[:magnum][:api][:bind_host] = my_ipaddress
  node.save
end

bind_port = network_settings[:api][:bind_port]
bind_host = network_settings[:api][:bind_host]

template node[:magnum][:config_file] do
  source "magnum.conf.erb"
  owner "root"
  group node[:magnum][:group]
  mode 0640
  variables(
    trustee: node[:magnum][:trustee],
    bind_host: bind_host,
    bind_port: bind_port,
    sql_connection: sql_connection,
    rabbit_settings: fetch_rabbitmq_settings,
    keystone_settings: KeystoneHelper.keystone_settings(node, :magnum),
    memcached_servers: memcached_servers
  )
end

# ssl
if node[:magnum][:api][:protocol] == "https"
  ssl_setup "setting up ssl for magnum" do
    generate_certs node[:magnum][:ssl][:generate_certs]
    certfile node[:magnum][:ssl][:certfile]
    keyfile node[:magnum][:ssl][:keyfile]
    group node[:magnum][:group]
    fqdn node[:fqdn]
    cert_required node[:magnum][:ssl][:cert_required]
    ca_certs node[:magnum][:ssl][:ca_certs]
  end
end
