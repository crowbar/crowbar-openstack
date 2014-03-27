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

rabbitmq_environment = node[:rabbitmq][:config][:environment]

vhostname = CrowbarRabbitmqHelper.get_ha_vhostname(node)
vip_primitive = "#{vhostname}-vip-admin"
fs_primitive = "#{rabbitmq_environment}-fs"
service_name = "#{rabbitmq_environment}-service"
group_name = "#{service_name}-group"

ip_addr = CrowbarRabbitmqHelper.get_listen_address(node)

if node[:rabbitmq][:ha][:storage][:mode] != "shared"
  raise "Invalid mode for HA storage!"
end
fs_params = {}
fs_params["device"] = node[:rabbitmq][:ha][:storage][:shared][:device]
fs_params["directory"] = "/var/lib/rabbitmq"
fs_params["fstype"] = node[:rabbitmq][:ha][:storage][:shared][:fstype]
unless node[:rabbitmq][:ha][:storage][:shared][:options].empty?
  fs_params["options"] = node[:rabbitmq][:ha][:storage][:shared][:options]
end

agent_name = "ocf:rabbitmq:rabbitmq-server"
rabbitmq_op = {}
rabbitmq_op["monitor"] = {}
rabbitmq_op["monitor"]["interval"] = "10s"

# Wait for all nodes to reach this point so we know that all nodes will have
# all the required packages installed before we create the pacemaker
# resources
crowbar_pacemaker_sync_mark "sync-rabbitmq_before_ha"

# Avoid races when creating pacemaker resources
crowbar_pacemaker_sync_mark "wait-rabbitmq_ha_storage"

# wait for DNS to be updated for hostname of virtual IP (otherwise, rabbitmq
# can't start)
vhostname = CrowbarRabbitmqHelper.get_ha_vhostname(node)
ruby_block "wait for rabbitmq vhostname" do
  block do
    require 'timeout'
    begin
      Timeout.timeout(120) do
        while ! ::Kernel.system("host #{vhostname} &> /dev/null")
          Chef::Log.debug("rabbitmq vhostname still not in DNS")
          sleep(2)
        end
      end
    rescue Timeout::Error
      message = "rabbitmq vhostname (#{vhostname}) not defined in DNS; manually re-applying the DNS proposal should unbreak this."
      Chef::Log.fatal(message)
      raise message
    end
  end # block
end # ruby_block

pacemaker_primitive vip_primitive do
  agent "ocf:heartbeat:IPaddr2"
  params ({
    "ip" => ip_addr,
  })
  op rabbitmq_op
  action :create
end

pacemaker_primitive fs_primitive do
  agent "ocf:heartbeat:Filesystem"
  params fs_params
  op rabbitmq_op
  action :create
end

crowbar_pacemaker_sync_mark "create-rabbitmq_ha_storage"

# wait for fs primitive to be active, and for the directory to be actually
# mounted; this is needed so we can change its ownership
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

# Ensure that the mounted directory is owned by rabbitmq; this works because we
# waited for the mount above. (This will obviously not be useful on nodes that
# are not using the mount resource; but it won't harm them either)
directory fs_params["directory"] do
  owner "rabbitmq"
  group "rabbitmq"
  mode 0750
end
# Now we can get the rabbitmq process to start since we know the directory is
# writable, so we can create the primitive for rabbitmq.

crowbar_pacemaker_sync_mark "wait-rabbitmq_ha_resources"

pacemaker_primitive service_name do
  agent agent_name
  params ({
    "nodename" => node[:rabbitmq][:nodename],
  })
  op rabbitmq_op
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

crowbar_pacemaker_sync_mark "create-rabbitmq_ha_resources"
