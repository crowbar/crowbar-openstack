#
# Cookbook Name:: monasca
# Recipe:: monasca-log-api
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

include_recipe "apache2"
include_recipe "apache2::mod_wsgi"

package "openstack-monasca-log-api"
package "python-python-memcached"

keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)
monasca_node = search(:node, "roles:monasca-server")[0]
monasca_net_ip = MonascaHelper.get_host_for_monitoring_url(monasca_node)

memcached_servers = MemcachedHelper.get_memcached_servers(
  if node[:monasca][:ha][:enabled]
    CrowbarPacemakerHelper.cluster_nodes(node, "monasca-server")
  else
    [node]
  end
)

memcached_instance("monasca") if node["roles"].include?("monasca-server")

template "/etc/monasca/log-api.conf" do
  source "monasca-log-api.conf.erb"
  owner "monasca-log-api"
  group "monasca"
  mode "0640"
  variables(
    keystone_settings: keystone_settings,
    memcached_servers: memcached_servers,
    kafka_url: "#{monasca_net_ip}:#{node[:monasca][:kafka][:port]}"
  )
end

crowbar_openstack_wsgi "WSGI entry for monasca-log-api" do
  bind_host "0.0.0.0"
  bind_port node[:monasca][:log_api][:bind_port]
  daemon_process "monasca-log-api"
  script_alias "/usr/bin/monasca-log-api-wsgi"
  user node[:monasca][:log_api][:user]
  group node[:monasca][:log_api][:group]
  ssl_enable node[:monasca][:api][:protocol] == "https"
  ssl_certfile node[:monasca][:ssl][:certfile]
  ssl_keyfile node[:monasca][:ssl][:keyfile]
  ssl_cacert node[:monasca][:ssl][:ca_certs] if
    node[:monasca][:ssl][:cert_required]
end

apache_site "monasca-log-api.conf" do
  enable true
end
