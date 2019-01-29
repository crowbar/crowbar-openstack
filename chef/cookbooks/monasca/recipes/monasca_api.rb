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

template "/etc/monasca/api.conf" do
  source "monasca-api.conf.erb"
  owner node[:monasca][:api][:user]
  group node[:monasca][:api][:group]
  mode "0640"
  variables(
    keystone_settings: keystone_settings,
    memcached_servers: memcached_servers,
    kafka_host: monasca_net_ip,
    influxdb_host: monasca_net_ip,
    sql_connection: sql_connection
  )
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
end

crowbar_openstack_wsgi "WSGI entry for monasca-api" do
  bind_host node[:monasca][:api][:bind_host]
  bind_port node[:monasca][:api][:bind_port]
  daemon_process "monasca-api"
  script_alias "/usr/bin/monasca-api-wsgi"
  user node[:monasca][:api][:user]
  group node[:monasca][:api][:group]
  ssl_enable node[:monasca][:api][:protocol] == "https"
  # FIXME(toabctl): the attributes do not even extist so SSL is broken!
  ssl_certfile nil # node[:monasca][:ssl][:certfile]
  ssl_keyfile nil # node[:monasca][:ssl][:keyfile]
  # if node[:monasca][:ssl][:cert_required]
  #  ssl_cacert node[:monasca][:ssl][:ca_certs]
  # end
end

apache_site "monasca-api.conf" do
  enable true
end
