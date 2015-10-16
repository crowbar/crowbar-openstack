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

glance_env_filter = " AND glance_config_environment:glance-config-#{node[:cinder][:glance_instance]}"
glance_servers = search(:node, "roles:glance-server#{glance_env_filter}") || []

if glance_servers.length > 0
  glance_server = glance_servers[0]
  glance_server = node if glance_server.name == node.name
  glance_server_host = CrowbarHelper.get_host_for_admin_url(glance_server, (glance_server[:glance][:ha][:enabled] rescue false))
  glance_server_protocol = glance_server[:glance][:api][:protocol]
  glance_server_port = glance_server[:glance][:api][:bind_port]
  glance_server_insecure = glance_server_protocol == "https" && glance_server[:glance][:ssl][:insecure]
else
  glance_server_host = nil
  glance_server_port = nil
  glance_server_protocol = nil
  glance_server_insecure = nil
end
Chef::Log.info("Glance server at #{glance_server_host}")

nova_apis = search(:node, "roles:nova-multi-controller") || []
if nova_apis.length > 0
  nova_api = nova_apis[0]
  nova_api_insecure = nova_api[:nova][:ssl][:enabled] && nova_api[:nova][:ssl][:insecure]
else
  nova_api_insecure = false
end

db_settings = fetch_database_settings

include_recipe "database::client"
include_recipe "#{db_settings[:backend_name]}::client"
include_recipe "#{db_settings[:backend_name]}::python-client"

db_password = ""
if node.roles.include? "cinder-controller"
  db_password = node[:cinder][:db][:password]
else
  # pickup password to database from cinder-controller node
  node_controllers = search(:node, "roles:cinder-controller") || []
  if node_controllers.length > 0
    db_password = node_controllers[0][:cinder][:db][:password]
  end
end

sql_connection = "#{db_settings[:url_scheme]}://#{node[:cinder][:db][:user]}:#{db_password}@#{db_settings[:address]}/#{node[:cinder][:db][:database]}"

my_ipaddress = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "admin").address
node[:cinder][:api][:bind_host] = my_ipaddress

node[:cinder][:my_ip] = my_ipaddress

if node[:cinder][:api][:protocol] == "https"
  if node[:cinder][:ssl][:generate_certs]
    package "openssl"
    ruby_block "generate_certs for cinder" do
      block do
        unless ::File.exists? node[:cinder][:ssl][:certfile] and ::File.exists? node[:cinder][:ssl][:keyfile]
          require "fileutils"

          Chef::Log.info("Generating SSL certificate for cinder...")

          [:certfile, :keyfile].each do |k|
            dir = File.dirname(node[:cinder][:ssl][k])
            FileUtils.mkdir_p(dir) unless File.exists?(dir)
          end

          # Generate private key
          %x(openssl genrsa -out #{node[:cinder][:ssl][:keyfile]} 4096)
          if $?.exitstatus != 0
            message = "SSL private key generation failed"
            Chef::Log.fatal(message)
            raise message
          end
          FileUtils.chown "root", node[:cinder][:group], node[:cinder][:ssl][:keyfile]
          FileUtils.chmod 0640, node[:cinder][:ssl][:keyfile]

          # Generate certificate signing requests (CSR)
          conf_dir = File.dirname node[:cinder][:ssl][:certfile]
          ssl_csr_file = "#{conf_dir}/signing_key.csr"
          ssl_subject = "\"/C=US/ST=Unset/L=Unset/O=Unset/CN=#{node[:fqdn]}\""
          %x(openssl req -new -key #{node[:cinder][:ssl][:keyfile]} -out #{ssl_csr_file} -subj #{ssl_subject})
          if $?.exitstatus != 0
            message = "SSL certificate signed requests generation failed"
            Chef::Log.fatal(message)
            raise message
          end

          # Generate self-signed certificate with above CSR
          %x(openssl x509 -req -days 3650 -in #{ssl_csr_file} -signkey #{node[:cinder][:ssl][:keyfile]} -out #{node[:cinder][:ssl][:certfile]})
          if $?.exitstatus != 0
            message = "SSL self-signed certificate generation failed"
            Chef::Log.fatal(message)
            raise message
          end

          File.delete ssl_csr_file  # Nobody should even try to use this
        end # unless files exist
      end # block
    end # ruby_block
  else # if generate_certs
    unless ::File.exists? node[:cinder][:ssl][:certfile]
      message = "Certificate \"#{node[:cinder][:ssl][:certfile]}\" is not present."
      Chef::Log.fatal(message)
      raise message
    end
    # we do not check for existence of keyfile, as the private key is allowed
    # to be in the certfile
  end # if generate_certs

  if node[:cinder][:ssl][:cert_required] and !::File.exists? node[:cinder][:ssl][:ca_certs]
    message = "Certificate CA \"#{node[:cinder][:ssl][:ca_certs]}\" is not present."
    Chef::Log.fatal(message)
    raise message
  end
end

availability_zone = nil
unless node[:crowbar_wall].nil? or node[:crowbar_wall][:openstack].nil?
  if node[:crowbar_wall][:openstack][:availability_zone] != ""
    availability_zone = node[:crowbar_wall][:openstack][:availability_zone]
  end
end

if node[:cinder][:ha][:enabled]
  admin_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "admin").address
  bind_host = admin_address
  bind_port = node[:cinder][:ha][:ports][:api]
else
  bind_host = node[:cinder][:api][:bind_open_address] ? "0.0.0.0" : node[:cinder][:api][:bind_host]
  bind_port = node[:cinder][:api][:bind_port]
end

template "/etc/cinder/cinder.conf" do
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
    glance_server_insecure: glance_server_insecure,
    nova_api_insecure: nova_api_insecure,
    availability_zone: availability_zone,
    keystone_settings: KeystoneHelper.keystone_settings(node, :cinder),
    strict_ssh_host_key_policy: node[:cinder][:strict_ssh_host_key_policy],
    default_availability_zone: node[:cinder][:default_availability_zone]
    )
end

node.save
