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
# Cookbook Name:: trove
# Recipe:: taskmanager
#

keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)

sql_connection = get_sql_connection

rabbitmq_trove_settings = get_rabbitmq_trove_settings

nova_url, nova_insecure = get_nova_details
cinder_url, cinder_insecure = get_cinder_details
object_store_url, object_store_insecure = get_objectstore_details

template "/etc/trove/trove-taskmanager.conf" do
  source "trove-taskmanager.conf.erb"
  owner node[:trove][:user]
  group node[:trove][:group]
  mode 00640
  variables(
    keystone_settings: keystone_settings,
    sql_connection: sql_connection,
    rabbit_default_settings: fetch_rabbitmq_settings,
    rabbit_trove_settings: rabbitmq_trove_settings,
    nova_url: nova_url,
    nova_insecure: nova_insecure,
    cinder_url: cinder_url,
    cinder_insecure: cinder_insecure,
    object_store_url: object_store_url,
    object_store_insecure: object_store_insecure
  )

  notifies :restart, "service[trove-taskmanager]"
end

trove_service("taskmanager")
