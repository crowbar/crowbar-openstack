#
# Copyright 2016, SUSE
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

ha_enabled = node[:swift][:ha][:enabled]
ssl_enabled = node[:swift][:ssl][:enabled]
swift_protocol = ssl_enabled ? "https" : "http"
proxy_node = get_instance("roles:swift-proxy")
public_proxy_host = CrowbarHelper.get_host_for_public_url(proxy_node, ssl_enabled, ha_enabled)

proposal_name = node[:swift][:config][:environment].gsub(/^swift-config-/, "")

# this needs to be both on storage nodes and proxy nodes
template "/etc/swift/container-sync-realms.conf" do
  source "container-sync-realms.conf.erb"
  owner "root"
  group node[:swift][:group]
  variables(
    key: node[:swift][:container_sync][:key],
    key2: node[:swift][:container_sync][:key2],
    cluster_name: "#{node[:domain]}_#{proposal_name}",
    proxy_url: "#{swift_protocol}://#{public_proxy_host}:#{node[:swift][:ports][:proxy]}/v1/"
  )
end
