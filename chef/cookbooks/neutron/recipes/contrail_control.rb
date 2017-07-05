#
# Copyright 2017 SUSE Linux GmBH
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
# Configurations to be set on the controller for neutron:
# # neutron.conf
# [DEFAULT]
# core_plugin = neutron_plugin_contrail.plugins.opencontrail.contrail_plugin.NeutronPluginContrailV2
# service_plugins = neutron_plugin_contrail.plugins.opencontrail.loadbalancer.v2.plugin.LoadBalancerPluginV2
#
# [quotas]
# quota_driver = neutron_plugin_contrail:plugins.opencontrail.quota.driver.QuotaDriver
#
# [service_providers]
# service_provider = LOADBALANCER:Opencontrail:neutron_plugin_contrail.plugins.opencontrail.loadbalancer.driver.OpenContrailLoadbalancer:default
#
# # Add new plugin opencontrail/ContrailPlugin.ini
#

# Install contrail-lib, neutron-plugin-contrail, python-contrail

node[:neutron][:platform][:contrail_control_pkgs].each { |p| package p }

keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)

# TODO(mmnelemane): metadata_proxy_shared_secret from nova servers needs to be 
# copied onto contrail-api server to ensure the contrail service can provide 
# metadata access to nova servers.
template "/etc/neutron/plugins/opencontrail/ContrailPlugin.ini" do
  cookbook "neutron"
  source "ContrailPlugin.ini.erb"
  mode "0640"
  owner "root"
  group node[:neutron][:platform][:group]
  variables(
    contrail_api_server_ip: node[:neutron][:contrail][:api_server_ip],
    contrail_api_server_port: node[:neutron][:contrail][:api_server_port],
    multi_tenancy: node[:neutron][:contrail][:multi_tenancy],
    contrail_analytics_api_ip: node[:neutron][:contrail][:analytics_api_ip],
    contrail_analytics_api_port: node[:neutron][:contrail][:analytics_api_port],
    keystone_settings: keystone_settings
  )
  notifies :restart, "service[#{node[:neutron][:platform][:service_name]}]"
end
