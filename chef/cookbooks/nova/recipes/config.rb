#
# Cookbook Name:: nova
# Recipe:: config
#
# Copyright 2010, 2011 Opscode, Inc.
# Copyright 2011 Dell, Inc.
# Copyright 2014, SUSE Linux Products GmbH
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

is_controller = node["roles"].include?("nova-controller")

my_ip_net = "admin"

# z/VM compute nodes might need a different "my_ip" setting to be accessible
# from the xCAT management node
if node["roles"].include?("nova-compute-zvm")
  my_ip_net = node["nova"]["zvm"]["zvm_xcat_network"]
end

node.set[:nova][:my_ip] =
  Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, my_ip_net).address

package "nova-common" do
  if %w(rhel suse).include?(node[:platform_family])
    package_name "openstack-nova"
  end
  action :install
end

# don't expose database connection to the compute clients
if is_controller
  db_settings = fetch_database_settings

  include_recipe "database::client"
  include_recipe "#{db_settings[:backend_name]}::client"
  include_recipe "#{db_settings[:backend_name]}::python-client"

  db_conn_scheme = db_settings[:url_scheme]
  if node[:platform_family] == "suse" && db_settings[:backend_name] == "mysql"
    # The C-extensions (python-mysql) can't be monkey-patched by eventlet. Therefore, when only one nova-conductor is present,
    # all DB queries are serialized. By using the pure-Python driver by default, eventlet can do it's job:
    db_conn_scheme = "mysql+pymysql"
  end

  db = node[:nova][:db]
  database_connection = \
    "#{db_conn_scheme}://#{db[:user]}:#{db[:password]}@#{db_settings[:address]}/#{db[:database]}"
else
  database_connection = nil
end

api = if is_controller
  node
else
  node_search_with_cache("roles:nova-controller").first
end

api_ha_enabled = api[:nova][:ha][:enabled]
admin_api_host = CrowbarHelper.get_host_for_admin_url(api, api_ha_enabled)
public_api_host = CrowbarHelper.get_host_for_public_url(api, api[:nova][:ssl][:enabled], api_ha_enabled)
Chef::Log.info("Api server found at #{admin_api_host} #{public_api_host}")

glance_servers = node_search_with_cache("roles:glance-server")
if glance_servers.length > 0
  glance_server = glance_servers[0]
  glance_server = node if glance_server.name == node.name
  glance_server_host = CrowbarHelper.get_host_for_admin_url(glance_server, (glance_server[:glance][:ha][:enabled] rescue false))
  glance_server_port = glance_server[:glance][:api][:bind_port]
  glance_server_protocol = glance_server[:glance][:api][:protocol]
  glance_server_insecure = glance_server_protocol == "https" && glance_server[:glance][:ssl][:insecure]
else
  glance_server_host = nil
  glance_server_port = nil
  glance_server_protocol = nil
  glance_server_insecure = nil
end
Chef::Log.info("Glance server at #{glance_server_host}")

# use memcached as a cache backend for nova-novncproxy
if api_ha_enabled
  memcached_nodes = CrowbarPacemakerHelper.cluster_nodes(node, "nova-controller")
  memcached_servers = memcached_nodes.map do |n|
    node_admin_ip = Chef::Recipe::Barclamp::Inventory.get_network_by_type(n, "admin").address
    "#{node_admin_ip}:#{n[:memcached][:port] rescue node[:memcached][:port]}"
  end
else
  node_admin_ip = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "admin").address
  memcached_servers = ["#{node_admin_ip}:#{node[:memcached][:port]}"]
end
memcached_servers.sort!

directory "/etc/nova" do
   mode 0755
   action :create
end

keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)

rbd_enabled = false

use_multipath = false

cinder_servers = node_search_with_cache("roles:cinder-controller")
if cinder_servers.length > 0
  cinder_server = cinder_servers[0]
  cinder_insecure = cinder_server[:cinder][:api][:protocol] == "https" && cinder_server[:cinder][:ssl][:insecure]
  use_multipath = cinder_server[:cinder][:use_multipath]

  if node.roles.include? "nova-compute-kvm"
    cinder_server[:cinder][:volumes].each do |volume|
      rbd_enabled = true if volume["backend_driver"] == "rbd"
    end
  end
else
  cinder_insecure = false
end

if rbd_enabled
  include_recipe "nova::ceph"
end

# FIXME: These attributes will be removed or re-used
# with ephemeral storage change. Right now they are
# disabled in nova.conf to prevent overwritting
# multi Ceph backends from Cinder
ceph_user = node[:nova][:rbd][:user]
ceph_uuid = node[:nova][:rbd][:secret_uuid]

neutron_servers = node_search_with_cache("roles:neutron-server")
if neutron_servers.length > 0
  neutron_server = neutron_servers[0]
  neutron_server = node if neutron_server.name == node.name
  neutron_protocol = neutron_server[:neutron][:api][:protocol]
  neutron_server_host = CrowbarHelper.get_host_for_admin_url(neutron_server, (neutron_server[:neutron][:ha][:server][:enabled] rescue false))
  neutron_server_port = neutron_server[:neutron][:api][:service_port]
  neutron_insecure = neutron_protocol == "https" && neutron_server[:neutron][:ssl][:insecure]
  neutron_service_user = neutron_server[:neutron][:service_user]
  neutron_service_password = neutron_server[:neutron][:service_password]
  neutron_dhcp_domain = neutron_server[:neutron][:dhcp_domain]
  neutron_ml2_drivers = neutron_server[:neutron][:ml2_type_drivers]
  neutron_has_tunnel = neutron_ml2_drivers.include?("gre") || neutron_ml2_drivers.include?("vxlan")
else
  neutron_server_host = nil
  neutron_server_port = nil
  neutron_service_user = nil
  neutron_service_password = nil
  neutron_dhcp_domain = "novalocal"
  neutron_has_tunnel = false
end
Chef::Log.info("Neutron server at #{neutron_server_host}")

has_itxt = false
oat_server = node
unless node[:nova][:itxt_instance].nil? || node[:nova][:itxt_instance].empty?
  env_filter = " AND inteltxt_config_environment:inteltxt-config-#{node[:nova][:itxt_instance]}"
  oat_servers = search(:node, "roles:oat-server#{env_filter}") || []
  unless oat_servers.empty?
    has_itxt = true
    oat_server = oat_servers[0]
    execute "fill_cert" do
      command <<-EOF
        echo | openssl s_client -connect "#{oat_server[:hostname]}:8443" -cipher DHE-RSA-AES256-SHA > /etc/nova/oat_certfile.cer || rm -fv /etc/nova/oat_certfile.cer
      EOF
      not_if { File.exist? "/etc/nova/oat_certfile.cer" }
    end
  end
end

# only put certificates in nova.conf for controllers; on compute nodes, we
# don't need them and specifying them results in the certificates being queried
# when creating clients for glance
if api[:nova][:ssl][:enabled] && is_controller
  api_ssl_certfile = api[:nova][:ssl][:certfile]
  api_ssl_keyfile = api[:nova][:ssl][:keyfile]
  api_ssl_cafile = api[:nova][:ssl][:ca_certs]
else
  api_ssl_certfile = ""
  api_ssl_keyfile = ""
  api_ssl_cafile = ""
end

# if there's no certificate for novnc, use the ones from nova-api
if api[:nova][:novnc][:ssl][:enabled] && is_controller
  if api[:nova][:novnc][:ssl][:certfile].empty?
    api_novnc_ssl_certfile = api[:nova][:ssl][:certfile]
    api_novnc_ssl_keyfile = api[:nova][:ssl][:keyfile]
  else
    api_novnc_ssl_certfile = api[:nova][:novnc][:ssl][:certfile]
    api_novnc_ssl_keyfile = api[:nova][:novnc][:ssl][:keyfile]
  end
else
  api_novnc_ssl_certfile = ""
  api_novnc_ssl_keyfile = ""
end

# only require certs for nova controller
if (api_ha_enabled || api == node) && \
    api[:nova][:ssl][:enabled] && is_controller
  if api[:nova][:ssl][:generate_certs]
    package "openssl"
    ruby_block "generate_certs for nova" do
      block do
        unless ::File.exist?(api[:nova][:ssl][:certfile]) && ::File.exist?(api[:nova][:ssl][:keyfile])
          require "fileutils"

          Chef::Log.info("Generating SSL certificate for nova...")

          [:certfile, :keyfile].each do |k|
            dir = File.dirname(api[:nova][:ssl][k])
            FileUtils.mkdir_p(dir) unless File.exist?(dir)
          end

          # Generate private key
          `openssl genrsa -out #{api[:nova][:ssl][:keyfile]} 4096`
          if $?.exitstatus != 0
            message = "SSL private key generation failed"
            Chef::Log.fatal(message)
            raise message
          end
          FileUtils.chown "root", api[:nova][:group], api[:nova][:ssl][:keyfile]
          FileUtils.chmod 0640, api[:nova][:ssl][:keyfile]

          # Generate certificate signing requests (CSR)
          conf_dir = File.dirname api[:nova][:ssl][:certfile]
          ssl_csr_file = "#{conf_dir}/signing_key.csr"
          ssl_subject = "\"/C=US/ST=Unset/L=Unset/O=Unset/CN=#{api[:fqdn]}\""
          `openssl req -new -key #{api[:nova][:ssl][:keyfile]} -out #{ssl_csr_file} -subj #{ssl_subject}`
          if $?.exitstatus != 0
            message = "SSL certificate signed requests generation failed"
            Chef::Log.fatal(message)
            raise message
          end

          # Generate self-signed certificate with above CSR
          `openssl x509 -req -days 3650 -in #{ssl_csr_file} -signkey #{api[:nova][:ssl][:keyfile]} -out #{api[:nova][:ssl][:certfile]}`
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
    unless ::File.size? api[:nova][:ssl][:certfile]
      message = "Certificate \"#{api[:nova][:ssl][:certfile]}\" is not present or empty."
      Chef::Log.fatal(message)
      raise message
    end
    # we do not check for existence of keyfile, as the private key is allowed
    # to be in the certfile
  end # if generate_certs

  if api[:nova][:ssl][:cert_required] && !::File.size?(api[:nova][:ssl][:ca_certs])
    message = "Certificate CA \"#{api[:nova][:ssl][:ca_certs]}\" is not present or empty."
    Chef::Log.fatal(message)
    raise message
  end
end

if (api_ha_enabled || api == node) && \
    api[:nova][:novnc][:ssl][:enabled] && is_controller
  # No check if we're using certificate info from nova-api
  unless ::File.size?(api_novnc_ssl_certfile) || api[:nova][:novnc][:ssl][:certfile].empty?
    message = "Certificate \"#{api_novnc_ssl_certfile}\" is not present or empty."
    Chef::Log.fatal(message)
    raise message
  end
end

admin_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "admin").address
metadata_bind_address = admin_address

if node[:nova][:ha][:enabled]
  bind_host = admin_address
  bind_port_api = node[:nova][:ha][:ports][:api]
  bind_port_api_ec2 = node[:nova][:ha][:ports][:api_ec2]
  bind_port_metadata = node[:nova][:ha][:ports][:metadata]
  bind_port_objectstore = node[:nova][:ha][:ports][:objectstore]
  bind_port_novncproxy = node[:nova][:ha][:ports][:novncproxy]
  bind_port_xvpvncproxy = node[:nova][:ha][:ports][:xvpvncproxy]
else
  bind_host = "0.0.0.0"
  bind_port_api = node[:nova][:ports][:api]
  bind_port_api_ec2 = node[:nova][:ports][:api_ec2]
  bind_port_metadata = node[:nova][:ports][:metadata]
  bind_port_objectstore = node[:nova][:ports][:objectstore]
  bind_port_novncproxy = node[:nova][:ports][:novncproxy]
  bind_port_xvpvncproxy = node[:nova][:ports][:xvpvncproxy]
end

# Allow to use some specific NICs for live migration
migration_host = if node[:nova][:migration][:network] == "admin"
  "%s"
else
  "#{node[:nova][:migration][:network]}.%s"
end

template "/etc/nova/nova.conf" do
  source "nova.conf.erb"
  user "root"
  group node[:nova][:group]
  mode 0640
  variables(
            bind_host: bind_host,
            bind_port_api: bind_port_api,
            bind_port_api_ec2: bind_port_api_ec2,
            bind_port_metadata: bind_port_metadata,
            bind_port_objectstore: bind_port_objectstore,
            bind_port_novncproxy: bind_port_novncproxy,
            bind_port_xvpvncproxy: bind_port_xvpvncproxy,
            dhcpbridge: "/usr/bin/nova-dhcpbridge",
            database_connection: database_connection,
            rabbit_settings: fetch_rabbitmq_settings,
            libvirt_type: node[:nova][:libvirt_type],
            ec2_host: admin_api_host,
            ec2_dmz_host: public_api_host,
            libvirt_migration: node[:nova]["use_migration"],
            migration_host: migration_host,
            shared_instances: node[:nova]["use_shared_instance_storage"],
            force_config_drive: node[:nova]["force_config_drive"],
            glance_server_protocol: glance_server_protocol,
            glance_server_host: glance_server_host,
            glance_server_port: glance_server_port,
            glance_server_insecure: glance_server_insecure || keystone_settings["insecure"],
            metadata_bind_address: metadata_bind_address,
            vncproxy_public_host: public_api_host,
            vncproxy_ssl_enabled: api[:nova][:novnc][:ssl][:enabled],
            vncproxy_cert_file: api_novnc_ssl_certfile,
            vncproxy_key_file: api_novnc_ssl_keyfile,
            memcached_servers: memcached_servers,
            neutron_protocol: neutron_protocol,
            neutron_server_host: neutron_server_host,
            neutron_server_port: neutron_server_port,
            neutron_insecure: neutron_insecure || keystone_settings["insecure"],
            neutron_service_user: neutron_service_user,
            neutron_service_password: neutron_service_password,
            neutron_dhcp_domain: neutron_dhcp_domain,
            neutron_has_tunnel: neutron_has_tunnel,
            keystone_settings: keystone_settings,
            cinder_insecure: cinder_insecure || keystone_settings["insecure"],
            use_multipath: use_multipath,
            ceph_user: ceph_user,
            ceph_uuid: ceph_uuid,
            ssl_enabled: api[:nova][:ssl][:enabled],
            ssl_cert_file: api_ssl_certfile,
            ssl_key_file: api_ssl_keyfile,
            ssl_cert_required: api[:nova][:ssl][:cert_required],
            ssl_ca_file: api_ssl_cafile,
            oat_appraiser_host: oat_server[:hostname],
            oat_appraiser_port: "8443",
            has_itxt: has_itxt
            )
end

# dependency for crowbar-nova-set-availability-zone
package "python-novaclient"

cookbook_file "crowbar-nova-set-availability-zone" do
  source "crowbar-nova-set-availability-zone"
  path "/usr/bin/crowbar-nova-set-availability-zone"
  mode "0755"
end
