
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

# We do the HA setup in two steps:
#  - we need to create the vip / storage resources before creating the
#    configuration files (that will be on the mounted device)
#  - we need to create the configuration files before starting postgresql (and
#    therefore creating the primitive for the service and the group)
# There's no magic, we have to follow that order.
#
# This is the first step.

database_environment = node[:database][:config][:environment]

vip_primitive = "#{CrowbarDatabaseHelper.get_ha_vhostname(node)}-vip-admin"
fs_primitive = "#{database_environment}-fs"
ms_name = "#{database_environment}-ms"

ip_addr = CrowbarDatabaseHelper.get_listen_address(node)

postgres_op = {}
postgres_op["monitor"] = {}
postgres_op["monitor"]["interval"] = "10s"

fs_params = {}
fs_params["directory"] = "/var/lib/pgsql"

if node[:database][:ha][:storage][:mode] == "drbd"
  drbd_resource = "postgresql"

  fs_params["device"] = crowbar_drbd "drbd for database" do
    resource_name drbd_resource
    size "50G"
  end
  fs_params["fstype"] = "xfs"
elsif node[:database][:ha][:storage][:mode] == "shared"
  fs_params["device"] = node[:database][:ha][:storage][:shared][:device]
  fs_params["fstype"] = node[:database][:ha][:storage][:shared][:fstype]
  unless node[:database][:ha][:storage][:shared][:options].empty?
    fs_params["options"] = node[:database][:ha][:storage][:shared][:options]
  end
else
  raise "Invalid mode for HA storage!"
end

# Wait for all nodes to reach this point so we know that all nodes will have
# all the required packages installed before we create the pacemaker
# resources
crowbar_pacemaker_sync_mark "sync-database_before_ha_storage" do
  revision node[:database]["crowbar-revision"]
end

# Avoid races when creating pacemaker resources
crowbar_pacemaker_sync_mark "wait-database_ha_storage" do
  revision node[:database]["crowbar-revision"]
end

if node[:database][:ha][:storage][:mode] == "drbd"
  drbd_primitive = "drbd_#{drbd_resource}"
  drbd_params = {}
  drbd_params["drbd_resource"] = drbd_resource

  pacemaker_primitive drbd_primitive do
    agent "ocf:linbit:drbd"
    params drbd_params
    op postgres_op
    action :create
  end

  pacemaker_ms ms_name do
    rsc drbd_primitive
    meta ({
      "master-max" => "1",
      "master-node-max" => "1",
      "clone-max" => "2",
      "clone-node-max" => "1",
      "notify" => "true"
    })
    action :create
  end

  ruby_block "wait for #{drbd_primitive} to be started" do
    block do
      begin
        # Check that the drbd resource is running
        cmd = "crm resource show #{ms_name} 2> /dev/null | grep -q \"Master\""
        if ! ::Kernel.system(cmd)
          Chef::Log.info("#{drbd_primitive} needs some cleanup")
          run = "crm resource cleanup #{drbd_primitive} 2> /dev/null"
          ::Kernel.system(run)
        end
      end
    end
  end # block
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

crowbar_pacemaker_sync_mark "create-database_ha_storage" do
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

# Ensure that the mounted directory is owned by postgres; this works because we
# waited for the mount above. (This will obviously not be useful on nodes that
# are not using the mount resource; but it won't harm them either)
directory fs_params["directory"] do
  owner "postgres"
  group "postgres"
  mode 0750
end

# We need to create the directory; it's usually done by postgresql on start,
# but for HA:
#  - we start postgresql later (after the config files have been created)
#  - we need the directory to be created to allow the templates to be created
#  - the ocf RA checks for the existence of this
directory "#{node[:postgresql][:dir]}" do
  owner "postgres"
  group "postgres"
  mode 0700
end
