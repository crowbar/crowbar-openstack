#
# Cookbook Name:: monasca
# Recipe:: monasca_api
#
# Copyright 2018, SUSE Linux GmbH.
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

package "openstack-monasca-api"

monasca_servers = search(:node, "roles:monasca-server")
monasca_net_ip = MonascaHelper.get_host_for_monitoring_url(monasca_servers[0])

keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)

if node[:monasca][:api][:protocol] == "https"
  ssl_setup "setting up ssl for monasca-api" do
    generate_certs node[:monasca][:ssl][:generate_certs]
    certfile node[:monasca][:ssl][:certfile]
    keyfile node[:monasca][:ssl][:keyfile]
    group node[:monasca][:api][:group]
    fqdn node[:fqdn]
    cert_required node[:monasca][:ssl][:cert_required]
    ca_certs node[:monasca][:ssl][:ca_certs]
  end
end

memcached_servers = MemcachedHelper.get_memcached_servers(
  if node[:monasca][:ha][:enabled]
    CrowbarPacemakerHelper.cluster_nodes(node, "monasca-server")
  else
    [node]
  end
)

memcached_instance("monasca") if node["roles"].include?("monasca-server")

# get Database data
db_auth = node[:monasca][:db_monapi].dup
sql_connection = fetch_database_connection_string(db_auth)
tsdb = node["monasca"]["tsdb"]

template "/etc/monasca/api.conf" do
  source "monasca-api.conf.erb"
  owner node[:monasca][:api][:user]
  group node[:monasca][:api][:group]
  mode "0640"
  variables(
    keystone_settings: keystone_settings,
    memcached_servers: memcached_servers,
    kafka_host: monasca_net_ip,
    tsdb_host: monasca_net_ip,
    sql_connection: sql_connection,
    tsdb: tsdb
  )
end

execute "apply mon database schema migration" do
  command "/usr/bin/monasca_db upgrade"
  action :run
  only_if do
    !node[:monasca][:db_monapi_synced] &&
      (!node[:monasca][:ha][:enabled] || CrowbarPacemakerHelper.is_cluster_founder?(node))
  end
end

# We want to keep a note that we've done the schema apply,
# so we don't do it again.
ruby_block "mark node for monasca mon db schema migration" do
  block do
    node.set[:monasca][:db_monapi_synced] = true
    node.save
  end
  not_if { node[:monasca][:db_monapi_synced] }
end

# influxdb user for monasca-api
ruby_block "Create influxdb user #{node["monasca"]["api"]["influxdb_user"]} " \
           "for database #{node['monasca']['db_monapi']['database']}" do
  block do
    InfluxDBHelper.create_user(node["monasca"]["api"]["influxdb_user"],
                               # FIXME(toabctl): Move password away from master settings
                               node["monasca"]["master"]["tsdb_mon_api_password"],
                               node["monasca"]["db_monapi"]["database"],
                               influx_host: monasca_net_ip)
  end
  only_if { tsdb == "influxdb" }
end

if tsdb == "cassandra"
  package "python-cassandra-driver"

  cassandra_admin_user = node[:monasca][:cassandra][:admin_user]
  default_password = node[:monasca][:cassandra][:admin_default_password]
  cassandra_admin_password = node[:monasca][:cassandra][:admin_password]
  admin_role = node[:monasca][:cassandra][:admin_role]
  api_role = node[:monasca][:cassandra][:monasca_api_role]
  persister_role = node[:monasca][:cassandra][:monasca_persister_role]

  ruby_block "Initialize password for superuser role" do
    condition_cmd = "/usr/bin/cqlsh -u #{cassandra_admin_user} -p '#{default_password}'"
    condition_cmd << " -e \"LIST ROLES\" #{monasca_net_ip}"
    block do
      CassandraHelper.set_password(admin_role, cassandra_admin_password,
                                   user: cassandra_admin_user,
                                   password: default_password,
                                   host: monasca_net_ip)
      Chef::Log.info "Superuser password has been initialized"
    end
    only_if condition_cmd
  end

  # Create Monasca roles
  roles = [api_role, persister_role]
  roles.each do |roles_item|
    ruby_block "Create role for #{roles_item}" do
      block do
        CassandraHelper.create_role_with_login(roles_item, cassandra_admin_password,
                                               user: cassandra_admin_user,
                                               password: cassandra_admin_password,
                                               host: monasca_net_ip)
      end
      retries 5
    end
  end

  # Apply Cassandra schema
  cmd = "/usr/bin/cqlsh -u #{cassandra_admin_user}"
  cmd << " -p '#{cassandra_admin_password}' #{monasca_net_ip}"
  cmd << " < /usr/share/monasca-api/schema/monasca_schema.cql"
  condition_cmd = "/usr/bin/cqlsh -u #{cassandra_admin_user}"
  condition_cmd << " -p '#{cassandra_admin_password}'"
  condition_cmd << " -e \"DESCRIBE KEYSPACES\" #{monasca_net_ip}"
  condition_cmd << " | grep -q monasca"
  execute "Apply Cassandra schema" do
    command cmd
    not_if condition_cmd
  end

  api_role = node[:monasca][:cassandra][:monasca_api_role]
  persister_role = node[:monasca][:cassandra][:monasca_persister_role]
  roles = [api_role, persister_role]
  roles.each do |roles_item|
    ruby_block "Grant read permissions for #{roles_item}" do
      block do
        CassandraHelper.grant_read_permissions(roles_item,
                                               user: cassandra_admin_user,
                                               password: cassandra_admin_password,
                                               host: monasca_net_ip)
      end
    end
  end

  ruby_block "Grant write permissions for persister" do
    block do
      CassandraHelper.grant_write_permissions(persister_role,
                                              user: cassandra_admin_user,
                                              password: cassandra_admin_password,
                                              host: monasca_net_ip)
    end
  end
end

crowbar_openstack_wsgi "WSGI entry for monasca-api" do
  bind_host node[:monasca][:api][:bind_host]
  bind_port node[:monasca][:api][:bind_port]
  daemon_process "monasca-api"
  script_alias "/usr/bin/monasca-api-wsgi"
  user node[:monasca][:api][:user]
  group node[:monasca][:api][:group]
  ssl_enable node[:monasca][:api][:protocol] == "https"
  ssl_certfile node[:monasca][:ssl][:certfile]
  ssl_keyfile node[:monasca][:ssl][:keyfile]
  ssl_cacert node[:monasca][:ssl][:ca_certs] if
    node[:monasca][:ssl][:cert_required]
end

apache_site "monasca-api.conf" do
  enable true
end
