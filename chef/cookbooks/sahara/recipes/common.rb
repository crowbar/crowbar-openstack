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

package "openstack-sahara"

network_settings = SaharaHelper.network_settings(node)
db_settings = fetch_database_settings

include_recipe "database::client"
include_recipe "#{db_settings[:backend_name]}::client"
include_recipe "#{db_settings[:backend_name]}::python-client"

# get Database data
db_password = node[:sahara][:db][:password]
sql_connection = "#{db_settings[:url_scheme]}://#{node[:sahara][:db][:user]}:"\
                 "#{db_password}@#{db_settings[:address]}/"\
                 "#{node[:sahara][:db][:database]}"

cinder_instance = node[:sahara][:cinder_instance]
heat_instance = node[:sahara][:heat_instance]
neutron_instance = node[:sahara][:neutron_instance]
nova_instance = node[:sahara][:nova_instance]

cinder_insecure = Barclamp::Config.load("openstack", "cinder", cinder_instance)["insecure"] || false
heat_insecure = Barclamp::Config.load("openstack", "heat", heat_instance)["insecure"] || false
neutron_insecure = Barclamp::Config.load("openstack", "neutron", neutron_instance)["insecure"] || false
nova_insecure = Barclamp::Config.load("openstack", "nova", nova_instance)["insecure"] || false

# use ceilometer?
ceilometers = search_env_filtered(:node, "roles:ceilometer-server")
use_ceilometer = !ceilometers.empty?

template node[:sahara][:config_file] do
  source "sahara.conf.erb"
  owner "root"
  group node[:sahara][:group]
  mode "0640"
  variables(
    bind_host: network_settings[:api][:bind_host],
    bind_port: network_settings[:api][:bind_port],
    sql_connection: sql_connection,
    rabbit_settings: fetch_rabbitmq_settings,
    keystone_settings: KeystoneHelper.keystone_settings(node, :sahara),
    cinder_insecure: cinder_insecure,
    heat_insecure: heat_insecure,
    neutron_insecure: neutron_insecure,
    nova_insecure: nova_insecure,
    use_ceilometer: use_ceilometer
  )
end

node.save
