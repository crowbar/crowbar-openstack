# Copyright 2014 SUSE
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

database_environment = node[:database][:config][:environment]

vip_primitive = "#{CrowbarDatabaseHelper.get_ha_vhostname(node)}-vip-admin"
fs_primitive = "#{database_environment}-fs"
service_name = "#{database_environment}-service"
group_name = "#{service_name}-group"

ip_addr = CrowbarDatabaseHelper.get_listen_address(node)

if node[:database][:ha][:storage][:mode] != "shared"
  raise "Invalid mode for HA storage!"
end
fs_params = {}
fs_params["device"] = node[:database][:ha][:storage][:shared][:device]
fs_params["directory"] = "/var/lib/pgsql"
fs_params["fstype"] = node[:database][:ha][:storage][:shared][:fstype]
unless node[:database][:ha][:storage][:shared][:options].empty?
  fs_params["options"] = node[:database][:ha][:storage][:shared][:options]
end

agent_name = "lsb:postgresql"
postgres_op = {}
postgres_op["monitor"] = {}
postgres_op["monitor"]["interval"] = "10s"

# Wait for all nodes to reach this point so we know that all nodes will have
# all the required packages installed before we create the pacemaker
# resources
crowbar_pacemaker_sync_mark "sync-database_before_ha" do
  revision node[:database]["crowbar-revision"]
end

# Avoid races when creating pacemaker resources
crowbar_pacemaker_sync_mark "wait-database_ha_resources" do
  revision node[:database]["crowbar-revision"]
end

pacemaker_primitive vip_primitive do
  agent "ocf:heartbeat:IPaddr2"
  params ({
    "ip" => ip_addr,
  })
  op postgres_op
  action :create
end

pacemaker_primitive fs_primitive do
  agent "ocf:heartbeat:Filesystem"
  params fs_params
  op postgres_op
  action :create
end

pacemaker_primitive service_name do
  agent agent_name
  op postgres_op
  action :create
end

pacemaker_group group_name do
  # Membership order *is* significant; VIPs should come first so
  # that they are available for the service to bind to.
  members [vip_primitive, fs_primitive, service_name]
  meta ({
    "is-managed" => true,
    "target-role" => "started"
  })
  action [ :create, :start ]
end

crowbar_pacemaker_sync_mark "create-database_ha_resources" do
  revision node[:database]["crowbar-revision"]
end

# wait for fs primitive to be active, and for the directory to be actually
# mounted; this is needed before we generate files in the directory
ruby_block "wait for #{fs_primitive} to be started" do
  block do
    require 'timeout'
    begin
      Timeout.timeout(20) do
        # Check that the fs resource is running
        cmd = "crm resource show #{fs_primitive} 2> /dev/null | grep -q \"is running on\""
        while ! ::Kernel.system(cmd)
          Chef::Log.debug("#{fs_primitive} still not started")
          sleep(2)
        end
        # Check that the fs resource is mounted, if it's running on this node
        cmd = "crm resource show #{fs_primitive} | grep -q \" #{node.hostname} *$\""
        if ::Kernel.system(cmd)
          cmd = "mount | grep -q \"on #{fs_params["directory"]} \""
          while ! ::Kernel.system(cmd)
            Chef::Log.debug("#{fs_params["directory"]} still not mounted")
            sleep(2)
          end
        end
      end
    rescue Timeout::Error
      message = "The #{fs_primitive} pacemaker resource is not started. Please manually check for an error."
      Chef::Log.fatal(message)
      raise message
    end
  end # block
end # ruby_block
