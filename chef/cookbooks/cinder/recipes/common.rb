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

if %w(rhel suse).include? node[:platform_family]
  package "openstack-cinder"
else
  package "cinder-common"
  package "python-mysqldb"
  package "python-cinder"
end

glance_servers = node_search_with_cache("roles:glance-server")

if glance_servers.length > 0
  glance_server = glance_servers[0]
  glance_server = node if glance_server.name == node.name
  glance_server_host = CrowbarHelper.get_host_for_admin_url(glance_server, (glance_server[:glance][:ha][:enabled] rescue false))
  glance_server_protocol = glance_server[:glance][:api][:protocol]
  glance_server_port = glance_server[:glance][:api][:bind_port]
  glance_show_storage_location = glance_server[:glance][:show_storage_location]
else
  glance_server_host = nil
  glance_server_port = nil
  glance_server_protocol = nil
  glance_show_storage_location = false
end
Chef::Log.info("Glance server at #{glance_server_host}")

glance_config = BarclampLibrary::Barclamp::Config.load(
  "openstack",
  "glance",
  node[:cinder][:glance_instance]
)
glance_insecure = glance_config["ssl"]["insecure"] || false

nova_insecure = BarclampLibrary::Barclamp::Config.load(
    "openstack", "nova"
)["ssl"]["insecure"] || false

db_settings = fetch_database_settings

include_recipe "database::client"
include_recipe "#{db_settings[:backend_name]}::client"
include_recipe "#{db_settings[:backend_name]}::python-client"

db_auth = node[:cinder][:db].dup
unless node.roles.include? "cinder-controller"
  # pickup password to database from cinder-controller node
  node_controllers = node_search_with_cache("roles:cinder-controller")
  if node_controllers.length > 0
    db_auth[:password] = node_controllers[0][:cinder][:db][:password]
  end
end

sql_connection = fetch_database_connection_string(db_auth)

dirty = false

my_ipaddress = Barclamp::Inventory.get_network_by_type(node, "admin").address
if node[:cinder][:api][:bind_host] != my_ipaddress
  node.set[:cinder][:api][:bind_host] = my_ipaddress
  dirty = true
end
if node[:cinder][:my_ip] != my_ipaddress
  node.set[:cinder][:my_ip] = my_ipaddress
  dirty = true
end

node.save if dirty

if node[:cinder][:api][:protocol] == "https"
  ssl_setup "setting up ssl for cinder" do
    generate_certs node[:cinder][:ssl][:generate_certs]
    certfile node[:cinder][:ssl][:certfile]
    keyfile node[:cinder][:ssl][:keyfile]
    group node[:cinder][:group]
    fqdn node[:fqdn]
    cert_required node[:cinder][:ssl][:cert_required]
    ca_certs node[:cinder][:ssl][:ca_certs]
  end
end

availability_zone = nil
unless node[:crowbar_wall].nil? or node[:crowbar_wall][:openstack].nil?
  if node[:crowbar_wall][:openstack][:availability_zone] != ""
    availability_zone = node[:crowbar_wall][:openstack][:availability_zone]
  end
end

bind_host, bind_port = CinderHelper.get_bind_host_port(node)

# lock path prevents race conditions for cinder-volume and nova-compute on same
# node. Keep code in sync between cinder and nova recipes. For reference check
# http://docs.openstack.org/releasenotes/nova/newton.html
need_shared_lock_path = node.roles.include?("cinder-volume") && \
  node.roles.any? { |role| /^nova-compute-/ =~ role }
if need_shared_lock_path
  group "openstack" do
    members "cinder"
    append true
  end
  include_recipe "crowbar-openstack::common"
end

memcached_servers = MemcachedHelper.get_memcached_servers(
  if node[:cinder][:ha][:enabled]
    CrowbarPacemakerHelper.cluster_nodes(node, "cinder-controller")
  else
    [node]
  end
)

memcached_instance("cinder") if node["roles"].include?("cinder-controller")

template node[:cinder][:config_file] do
  source "cinder.conf.erb"
  owner "root"
  group node[:cinder][:group]
  mode 0640
  variables(
    bind_host: bind_host,
    bind_port: bind_port,
    use_multi_backend: node[:cinder][:use_multi_backend],
    volumes: node[:cinder][:volumes],
    sql_connection: sql_connection,
    rabbit_settings: fetch_rabbitmq_settings,
    glance_server_protocol: glance_server_protocol,
    glance_server_host: glance_server_host,
    glance_server_port: glance_server_port,
    glance_server_insecure: glance_insecure,
    need_shared_lock_path: need_shared_lock_path,
    show_storage_location: glance_show_storage_location,
    nova_api_insecure: nova_insecure,
    availability_zone: availability_zone,
    keystone_settings: KeystoneHelper.keystone_settings(node, :cinder),
    strict_ssh_host_key_policy: node[:cinder][:strict_ssh_host_key_policy],
    default_availability_zone: node[:cinder][:default_availability_zone],
    default_volume_type: node[:cinder][:default_volume_type],
    memcached_servers: memcached_servers
    )
end
