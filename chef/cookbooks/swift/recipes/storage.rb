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

skip_setup = node[:swift][:devs].nil?

include_recipe "swift::disks"
#include_recipe 'swift::auth'
# Note: we always want to setup rsync, even if we do not do anything else; this
# will allow the ring-compute node to push the rings.
include_recipe "swift::rsync"

if skip_setup
  # If we have no device yet, then it simply means that we haven't looked for
  # devices yet, which also means that we won't have rings at this point in
  # time; we just need to discover the disks (with the recipes above).
  Chef::Log.info("Not setting up swift-{account,container,object} daemons; this chef run is only used to find disks.")
  return
end

if node.roles.include?("swift-ring-compute") && !(::File.exist? "/etc/swift/object.ring.gz")
  Chef::Log.info("Not setting up swift-{account,container,object} daemons; this chef run is only used to compute the rings.")
  return
end

%w{swift-container swift-object swift-account}.each do |pkg|
  pkg = "openstack-#{pkg}" if %w(rhel suse).include?(node[:platform_family])
  package pkg
end

storage_ip = Swift::Evaluator.get_ip_by_type(node,:storage_ip_expr)

memcached_ips = search_env_filtered(:node, "roles:swift-proxy").map do |x|
  "#{Swift::Evaluator.get_ip_by_type(x, :admin_ip_expr)}:11211"
end.sort

%w{account-server object-expirer object-server container-server}.each do |service|
  template "/etc/swift/#{service}.conf" do
    source "#{service}.conf.erb"
    owner "root"
    group node[:swift][:group]
    variables({
      uid: node[:swift][:user],
      gid: node[:swift][:group],
      storage_net_ip: storage_ip,
      memcached_ips: memcached_ips.join(", "),
      server_num: 1,  ## could allow multiple servers on the same machine
      debug: node[:swift][:debug]
    })
  end
end

svcs = %w{swift-object swift-object-auditor swift-object-expirer swift-object-replicator swift-object-updater}
svcs += %w{swift-container swift-container-auditor swift-container-replicator swift-container-sync swift-container-updater}
svcs += %w{swift-account swift-account-reaper swift-account-auditor swift-account-replicator}

## make sure to fetch ring files from the ring compute node
compute_nodes = search_env_filtered(:node, "roles:swift-ring-compute")
if (!compute_nodes.nil? and compute_nodes.length > 0 )
  compute_node_addr  = Swift::Evaluator.get_ip_by_type(compute_nodes[0],:storage_ip_expr)
  log("ring compute found on: #{compute_nodes[0][:fqdn]} using: #{compute_node_addr}") { level :debug }

  %w{container account object}.each do |ring|
    execute "pull #{ring} ring" do
      user node[:swift][:user]
      group node[:swift][:group]
      command "rsync #{node[:swift][:user]}@#{compute_node_addr}::ring/#{ring}.ring.gz ."
      cwd "/etc/swift"
      ignore_failure true
    end
  end

  svcs.each do |svc|
    ring = svc.gsub("swift-", "").gsub(/-.*/, "")
    unless %w{container account object}.include? ring
      message = "Internal error: cannot find ring matching service \"#{svc}\""
      Chef::Log.fatal(message)
      raise message
    end

    service svc do
      service_name "openstack-#{svc}" if %w(rhel suse).include?(node[:platform_family])
      if (platform?("ubuntu") && node.platform_version.to_f >= 10.04)
        restart_command "status #{svc} 2>&1 | grep -q Unknown || restart #{svc}"
        stop_command "stop #{svc}"
        start_command "start #{svc}"
        status_command "status #{svc} | cut -d' ' -f2 | cut -d'/' -f1 | grep start"
      end
      supports status: true, restart: true
      action [:enable, :start]
      subscribes :restart, resources(template: "/etc/swift/swift.conf")
      subscribes :restart, resources(template: "/etc/swift/#{ring}-server.conf")
      if svc == "swift-container-sync"
        subscribes :restart, resources(template: "/etc/swift/container-sync-realms.conf")
      elsif svc == "swift-object-expirer"
        subscribes :restart, resources(template: "/etc/swift/object-expirer.conf")
      end
      only_if { ::File.exist? "/etc/swift/#{ring}.ring.gz" }
    end
  end
end

node.set["swift"]["storage_init_done"] = true

###
# let the monitoring tools know what services should be running on this node.
node.set[:swift][:monitor] = {}
node.set[:swift][:monitor][:svcs] = svcs
node.set[:swift][:monitor][:ports] = { object: 6000, container: 6001, account: 6002 }
node.save

if node["swift"]["use_slog"]
  log ("installing slogging") { level :info }
  include_recipe "swift::slog"
end
