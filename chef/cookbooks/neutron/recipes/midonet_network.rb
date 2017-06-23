#
# Copyright 2017 SUSE
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

node[:neutron][:platform][:midonet_network_pkgs].each { |p| package p }

zookeeper_hosts = node_search_with_cache("roles:neutron-server") || []
zookeeper_hosts = zookeeper_hosts.map do |h|
  h.name + ":2181"
end

template "/etc/midolman/midolman.conf" do
  source "midolman.conf.erb"
  owner "root"
  group "root"
  mode 0o640
  variables(
    zookeeper_hosts: zookeeper_hosts.join(",")
  )
end

midolman_template = "default"
ruby_block "configure midolman" do
  block do
    `mn-conf template-set -h local -t #{midolman_template}`
    `touch /etc/midolman/midolman-configured`
  end
  not_if do
    File.exist?("/etc/midolman/midolman-configured")
  end
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

ruby_block "backup default midolman config" do
  block do
    `mv /etc/midolman/midolman-env.sh /etc/midolman/midolman-env.sh.default`
  end
  not_if do
    File.exist?("/etc/midolman/midolman-env.sh.default")
  end
end

link "/etc/midolman/midolman-env.sh" do
  to "/etc/midolman/midolman-env.sh.#{midolman_template}"
end

service "midolman.service" do
  supports status: true, restart: true
  action [:enable, :start]
end
