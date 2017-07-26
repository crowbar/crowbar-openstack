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

return unless node["roles"].include?("nagios-client")

####
# if monitored by nagios, install the nrpe commands

return if node[:swift][:monitor].nil?

proxy_svcs = ["swift-proxy", "memcached"]
proxy_ports = { proxy: node[:swift][:ports][:proxy] }

# keep in sync with definition in storage.rb
storage_svcs = [
  "swift-object", "swift-object-auditor", "swift-object-expirer",
  "swift-object-replicator", "swift-object-updater",
  "swift-container", "swift-container-auditor", "swift-container-replicator",
  "swift-container-sync", "swift-container-updater",
  "swift-account", "swift-account-reaper", "swift-account-auditor", "swift-account-replicator"
]
storage_ports = { object: 6200, container: 6201, account: 6202 }

swift_svcs = []
swift_ports = {}

if node.roles.includes?("swift-proxy")
  swift_svcs.concat(proxy_svcs)
  swift_ports.merge!(proxy_ports)
end

if node.roles.includes?("swift-storage")
  swift_svcs.concat(storage_svcs)
  swift_ports.merge!(storage_ports)
end

swift_svcs.flatten!

storage_net_ip = Swift::Evaluator.get_ip_by_type(node,:storage_ip_expr)

log ("will monitor swift svcs: #{swift_svcs.join(',')} and ports #{swift_ports.values.join(',')} on storage_net_ip #{storage_net_ip}")

include_recipe "nagios::common"

template "/etc/nagios/nrpe.d/swift_nrpe.cfg" do
  source "swift_nrpe.cfg.erb"
  mode "0644"
  group node[:nagios][:group]
  owner node[:nagios][:user]
  variables(
    svcs: swift_svcs,
    swift_ports: swift_ports,
    storage_net_ip: storage_net_ip
  )
  notifies :restart, "service[nagios-nrpe-server]"
end
