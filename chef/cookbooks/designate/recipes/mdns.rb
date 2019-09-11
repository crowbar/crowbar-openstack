# Copyright 2018 SUSE Linux GmbH
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
# Cookbook Name:: designate
# Recipe:: mdns
#

require "yaml"

dns_all = node_search_with_cache("roles:dns-server")
dnsservers = dns_all.map do |n|
  Chef::Recipe::Barclamp::Inventory.get_network_by_type(n, "admin").address
end

designate_servers = node_search_with_cache("roles:designate-server")

# hidden masters are designate-mdns services, in ha this service will be running on multiple
# hosts and any host can be asked to update a zone on the pool target(s).
# We use the vip for the cluster in case of HA.
hiddenmasters = if node[:designate][:ha][:enabled]
  [CrowbarPacemakerHelper.cluster_vip(node, "admin")]
else
  designate_servers.map do |n|
    Barclamp::Inventory.get_network_by_type(n, "admin").address
  end
end

# One could have multiple pools in desginate. And
# Desginate needs to have a default pool, this pools
# id is hardcoded in the designate conf. By reusing that
# id we let designate know how crowbar's deployment of
# dns servers looks like.
ns_records = dns_all.map { |dnss| { "hostname" => "public-#{dnss[:fqdn]}.", "priority" => 1 } }
pools = [{
  "name" => "default-bind",
  "description" => "Default BIND9 Pool",
  "id" => "794ccc2c-d751-44fe-b57f-8894c9f5c842",
  "attributes" => {},
  "ns_records" => ns_records,
  "nameservers" => dnsservers.map { |ip| { "host" => ip, "port" => 53 } },
  "also_notifies" => [],
  "targets" => dnsservers.map do |ip|
    {
      "type" => "bind9",
      "description" => "BIND9 Server",
      "masters" => hiddenmasters.map { |hm| { "host" => hm, "port" => 5354 } },
      "options" => {
        "host" => ip,
        "port" => 53,
        "rndc_host" => ip,
        "rndc_port" => 953,
        "rndc_key_file" => "/etc/designate/rndc.key"
      }
    }
  end
}]

file "/etc/designate/pools.crowbar.yaml" do
  owner "root"
  group node[:designate][:group]
  mode "0640"
  content pools.to_yaml
  not_if { ::File.exist?("/etc/designate/pools.crowbar.yaml") }
end

template "/etc/designate/rndc.key" do
  source "rndc.key.erb"
  owner "root"
  group node[:designate][:group]
  mode "0640"
  variables(rndc_key: dns_all.first[:dns][:designate_rndc_key])
end

ha_enabled = node[:designate][:ha][:enabled]

execute "designate-manage pool update" do
  command "designate-manage pool update --file /etc/designate/pools.crowbar.yaml"
  user node[:designate][:user]
  group node[:designate][:group]
  # We only do the pool update the first time, and only if we're not doing HA or if we
  # are the founder of the HA cluster (so that it's really only done once).
  only_if do
    !node[:designate][:pool_updated] &&
      (!ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node))
  end
end

# We want to keep a note that we've done a pool update, so we don't do it again.
# If we were doing that outside a ruby_block, we would add the note in the
# compile phase, before the actual pool update is done (which is wrong, since it
# could possibly not be reached in case of errors).
ruby_block "mark node for designate-manage pool update" do
  block do
    node.set[:designate][:pool_updated] = true
    node.save
  end
  action :nothing
  subscribes :create, "execute[designate-manage pool update]", :immediately
end

designate_service "mdns"
