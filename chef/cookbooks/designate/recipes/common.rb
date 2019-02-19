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

package "openstack-designate"

network_settings = DesignateHelper.network_settings(node)
db_settings = fetch_database_settings

include_recipe "database::client"
include_recipe "#{db_settings[:backend_name]}::client"
include_recipe "#{db_settings[:backend_name]}::python-client"

public_host = CrowbarHelper.get_host_for_public_url(node,
                                                    node[:designate][:api][:protocol] == "https",
                                                    node[:designate][:ha][:enabled])

# get Database data
sql_connection = fetch_database_connection_string(node[:designate][:db])

memcached_servers = MemcachedHelper.get_memcached_servers(
  if node[:designate][:ha][:enabled]
    CrowbarPacemakerHelper.cluster_nodes(node, "designate-server")
  else
    [node]
  end
)

memcached_instance("designate") if node["roles"].include?("designate-server")

api_protocol = node[:designate][:api][:protocol]

template node[:designate][:config_file] do
  source "designate.conf.erb"
  owner "root"
  group node[:designate][:group]
  mode "0640"
  variables(
    bind_host: network_settings[:api][:bind_host],
    bind_port: network_settings[:api][:bind_port],
    api_base_uri: "#{api_protocol}://#{public_host}:#{node[:designate][:api][:bind_port]}",
    sql_connection: sql_connection,
    rabbit_settings: fetch_rabbitmq_settings,
    keystone_settings: KeystoneHelper.keystone_settings(node, :designate),
    memcached_servers: memcached_servers
  )
end
