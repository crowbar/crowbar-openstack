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
sql_connection = fetch_database_connection_string(node[:sahara][:db])

cinder_instance = node[:sahara][:cinder_instance]
heat_instance = node[:sahara][:heat_instance]
neutron_instance = node[:sahara][:neutron_instance]
nova_instance = node[:sahara][:nova_instance]

cinder_insecure = Barclamp::Config.load(
  "openstack", "cinder", cinder_instance
)["ssl"]["insecure"] || false

heat_insecure = Barclamp::Config.load(
  "openstack", "heat", heat_instance
)["ssl"]["insecure"] || false

neutron_insecure = Barclamp::Config.load(
  "openstack", "neutron", neutron_instance
)["ssl"]["insecure"] || false

nova_insecure = Barclamp::Config.load(
  "openstack", "nova", nova_instance
)["ssl"]["insecure"] || false

use_ceilometer = !Barclamp::Config.load("openstack", "ceilometer").empty?

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
