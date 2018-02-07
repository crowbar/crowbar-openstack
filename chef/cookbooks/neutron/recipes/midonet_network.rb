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

if node.roles.include?("neutron-network") && node[:neutron][:networking_plugin] == "midonet"
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
    only_if do
      !node[:neutron][:ha][:server][:enabled] ||
        CrowbarPacemakerHelper.is_cluster_founder?(node)
    end
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

  ruby_block "mark node for midolman" do
    block do
      node.set[:neutron][:midolman_installed] = true
      node.save
    end
    subscribes :run, "service[midolman.service]", :immediately
  end
end

if node.roles.include?("neutron-server") && node[:neutron][:networking_plugin] == "midonet"
  node[:neutron][:platform][:midonet_controller_pkgs].each { |p| package p }

  midonet_nodes = node[:neutron][:elements][:"neutron-network"] || []
  if node.key?("nova")
    midonet_nodes += node[:nova][:elements][:"nova-compute-#{node[:nova][:libvirt_type]}"]
  end
  Chef::Log.debug("Found midonet_nodes: #{midonet_nodes}")

  # Check whether those nodes have already run.
  midolman_installed = true
  midonet_nodes.each do |node_name|
    midonet_node = Chef::Node.load(node_name)
    if midonet_node.key?(:neutron) && midonet_node[:neutron].key?("midolman_installed")
      midolman_installed &&= midonet_node[:neutron]["midolman_installed"]
    end
  end
  if midolman_installed
    Chef::Log.debug("Midolman is installed")
    midonet_nodes = midonet_nodes.map do |n|
      Chef::Recipe::Barclamp::Inventory.get_network_by_type(Chef::Node.load(n), "admin").address
    end.join(" ")

    Chef::Log.debug("Setting up tunnel-zone on the following nodes:")
    Chef::Log.debug(midonet_nodes.to_s)

    template "/etc/midonet/create-tunnel-zone.sh" do
      source "midonet-create-tunnel-zone.sh.erb"
      owner "root"
      group "root"
      mode 0o750
      variables(
        node: node,
        midonet_nodes: midonet_nodes
      )
      notifies :run, "execute[create tunnel-zone #{node[:neutron][:midonet][:tunnel_zone]}]"
    end

    execute "create tunnel-zone #{node[:neutron][:midonet][:tunnel_zone]}" do
      command "/bin/bash /etc/midonet/create-tunnel-zone.sh"
      not_if { midonet_nodes.empty? }
    end
  else
    Chef::Log.info("Midonet is not installed yet")
  end
end
