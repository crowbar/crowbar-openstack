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

package "openstack-manila"

db_settings = fetch_database_settings

include_recipe "database::client"
include_recipe "#{db_settings[:backend_name]}::client"
include_recipe "#{db_settings[:backend_name]}::python-client"

# get Database data
db_auth = node[:manila][:db].dup
unless node.roles.include? "manila-server"
  # pickup password to database from manila-server node
  node_servers = node_search_with_cache("roles:manila-server")
  if node_servers.length > 0
    db_auth[:password] = node_servers[0][:manila][:db][:password]
  end
end

sql_connection = fetch_database_connection_string(db_auth)

# address/port binding
my_ipaddress = Barclamp::Inventory.get_network_by_type(node, "admin").address

dirty = false
if node[:manila][:my_ip] != my_ipaddress
  node.set[:manila][:my_ip] = my_ipaddress
  dirty = true
end
if node[:manila][:api][:bind_host] != my_ipaddress
  node.set[:manila][:api][:bind_host] = my_ipaddress
  dirty = true
end
node.save if dirty

bind_host, bind_port = ManilaHelper.get_bind_host_port(node)

# get Neutron data (copied from nova.conf.erb)
# TODO(toabctl): Seems that this code is used in different barclamps.
# Should be shared
neutron_servers = node_search_with_cache("roles:neutron-server")
if neutron_servers.length > 0
  neutron_server = neutron_servers[0]
  neutron_server = node if neutron_server.name == node.name
  neutron_protocol = neutron_server[:neutron][:api][:protocol]
  neutron_server_host = CrowbarHelper.get_host_for_admin_url(
    neutron_server,
    (neutron_server[:neutron][:ha][:server][:enabled] || false))
  neutron_server_port = neutron_server[:neutron][:api][:service_port]
  neutron_service_user = neutron_server[:neutron][:service_user]
  neutron_service_password = neutron_server[:neutron][:service_password]
  Chef::Log.info("Neutron server at #{neutron_server_host}")
else
  neutron_protocol = nil
  neutron_server_host = nil
  neutron_server_port = nil
  neutron_service_user = nil
  neutron_service_password = nil
  Chef::Log.warn("Neutron server not found")
end

neutron_config = Barclamp::Config.load("openstack", "neutron", node[:manila][:neutron_instance])
neutron_insecure = CrowbarOpenStackHelper.insecure(neutron_config)

# get Nova data
nova = node_search_with_cache("roles:nova-controller")
if nova.length > 0
  nova = nova[0]
  nova_admin_username = nova[:nova][:service_user]
  nova_admin_password = nova[:nova][:service_password]
else
  nova_admin_username = nil
  nova_admin_password = nil
  Chef::Log.warn("nova-controller not found")
end

nova_config = Barclamp::Config.load("openstack", "nova", node[:manila][:nova_instance])
nova_insecure = CrowbarOpenStackHelper.insecure(nova_config)

# get Cinder data
cinder = node_search_with_cache("roles:cinder-controller")
if cinder.length > 0
  cinder = cinder[0]
  cinder_admin_username = cinder[:cinder][:service_user]
  cinder_admin_password = cinder[:cinder][:service_password]
else
  cinder_admin_username = nil
  cinder_admin_password = nil
  Chef::Log.warn("cinder-controller not found")
end

cinder_config = Barclamp::Config.load("openstack", "cinder", node[:manila][:cinder_instance])
cinder_insecure = CrowbarOpenStackHelper.insecure(cinder_config)

enabled_share_protocols = ["NFS", "CIFS"]
enabled_share_protocols << ["CEPHFS"] if ManilaHelper.has_cephfs_share? node

memcached_servers = MemcachedHelper.get_memcached_servers([node])

memcached_instance("manila") if node["roles"].include?("manila-server")

template node[:manila][:config_file] do
  source "manila.conf.erb"
  owner "root"
  group node[:manila][:group]
  mode 0640
  variables(
    shares: node[:manila][:shares],
    enabled_share_protocols: enabled_share_protocols,
    bind_host: bind_host,
    bind_port: bind_port,
    sql_connection: sql_connection,
    default_share_type: node[:manila][:default_share_type],
    rabbit_settings: fetch_rabbitmq_settings,
    keystone_settings: KeystoneHelper.keystone_settings(node, :manila),
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
    cinder_admin_password: cinder_admin_password,
    memcached_servers: memcached_servers
  )
end

# ssl
if node[:manila][:api][:protocol] == "https"
  ssl_setup "setting up ssl for manila" do
    generate_certs node[:manila][:ssl][:generate_certs]
    certfile node[:manila][:ssl][:certfile]
    keyfile node[:manila][:ssl][:keyfile]
    group node[:manila][:group]
    fqdn node[:fqdn]
    cert_required node[:manila][:ssl][:cert_required]
    ca_certs node[:manila][:ssl][:ca_certs]
  end
end
