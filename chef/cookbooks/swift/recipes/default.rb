#
# Copyright 2011, Dell
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
# Author: andi abes
#

package "curl"

case node[:platform_family]
when "suse", "rhel"
  package "openstack-swift"
else
  package "swift"
end

template node[:swift][:config_file] do
  owner "root"
  group node[:swift][:group]
  source "swift.conf.erb"
 variables( {
       swift_cluster_hash: node[:swift][:cluster_hash]
 })
end

proxy_nodes = node_search_with_cache("roles:swift-proxy")
unless proxy_nodes.empty?
  proxy_node = proxy_nodes.first
  ha_enabled = node[:swift][:ha][:enabled]
  ssl_enabled = node[:swift][:ssl][:enabled]

  swift_protocol = ssl_enabled ? "https" : "http"
  public_proxy_host = CrowbarHelper.get_host_for_public_url(proxy_node, ssl_enabled, ha_enabled)

  proposal_name = node[:swift][:config][:environment].gsub(/^swift-config-/, "")

  # this needs to be both on storage nodes and proxy nodes
  template node[:swift][:container_config_file] do
    source "container-sync-realms.conf.erb"
    owner "root"
    group node[:swift][:group]
    mode "0640"
    variables(
      key: node[:swift][:container_sync][:key],
      key2: node[:swift][:container_sync][:key2],
      cluster_name: "#{node[:domain]}_#{proposal_name}",
      proxy_url: "#{swift_protocol}://#{public_proxy_host}:#{node[:swift][:ports][:proxy]}/v1/"
    )
  end
end

if node.roles.include?("logging-client") || node.roles.include?("logging-server")
  rsyslog_version = `rsyslogd -v | head -1 | sed -e "s/^rsyslogd \\(.*\\), .*$/\\1/"`
  # log swift components into separate log files
  template "/etc/rsyslog.d/11-swift.conf" do
    source "11-swift.conf.erb"
    mode "0644"
    variables(rsyslog_version: rsyslog_version)
    notifies :restart, "service[rsyslog]"
    only_if { node[:platform_family] == "suse" } # other distros might not have /var/log/swift
  end
end
