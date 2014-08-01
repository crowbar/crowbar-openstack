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

vhostname = CrowbarRabbitmqHelper.get_ha_vhostname(node)
drbd_resource = "rabbitmq"

vip_primitive = "vip-admin-#{vhostname}"
service_name = "rabbitmq"
fs_primitive = "fs-#{service_name}"
drbd_primitive = "drbd-#{drbd_resource}"
ms_name = "ms-#{drbd_primitive}"
group_name = "g-#{service_name}"

ip_addr = CrowbarRabbitmqHelper.get_listen_address(node)

fs_params = {}
fs_params["directory"] = "/var/lib/rabbitmq"
if node[:rabbitmq][:ha][:storage][:mode] == "drbd"
  crowbar_pacemaker_drbd drbd_resource do
    size "#{node[:rabbitmq][:ha][:storage][:drbd][:size]}G"
    action :nothing
  end.run_action(:create)

  fs_params["device"] = node["drbd"]["rsc"][drbd_resource]["device"]
  fs_params["fstype"] = "xfs"
elsif node[:rabbitmq][:ha][:storage][:mode] == "shared"
  fs_params["device"] = node[:rabbitmq][:ha][:storage][:shared][:device]
  fs_params["fstype"] = node[:rabbitmq][:ha][:storage][:shared][:fstype]
  unless node[:rabbitmq][:ha][:storage][:shared][:options].empty?
    fs_params["options"] = node[:rabbitmq][:ha][:storage][:shared][:options]
  end
else
  raise "Invalid mode for HA storage!"
end

agent_name = "ocf:rabbitmq:rabbitmq-server"
rabbitmq_op = {}
rabbitmq_op["monitor"] = {}
rabbitmq_op["monitor"]["interval"] = "10s"

# Wait for all "rabbitmq" nodes to reach this point so we know that 
# they will have all the required packages installed and configuration 
# files updated before we create the pacemaker resources.
crowbar_pacemaker_sync_mark "sync-rabbitmq_before_ha_storage"

# Avoid races when creating pacemaker resources
crowbar_pacemaker_sync_mark "wait-rabbitmq_ha_storage"

if node[:rabbitmq][:ha][:storage][:mode] == "drbd"
  drbd_params = {}
  drbd_params["drbd_resource"] = drbd_resource

  # Careful here: when creating the DRBD resources, we should in theory create
  # the primitive and the ms resources in one transaction. This is what is
  # expected by the drbd OCF agent, which checks (for the primitive) that the
  # meta bits (like clone-max), that are supposed to be inherited from the
  # required ms resource, are present.
  #
  # When that check fails, we can see this error:
  #   ERROR: meta parameter misconfigured, expected clone-max -le 2, but found unset.
  # which will cause fencing (the resource is not supposed to start, but the
  # monitoring op fails, so pacemaker tries to stop the resource to be safe,
  # and that fails too, leading to fencing).
  #
  # However, we cannot create the two resources in one transaction. So what we
  # do instead is on initial creation (and only in that case), we mark the drbd
  # primitive as unmanaged (that will cause the failure to not be fatal, with
  # no fencing), and we clean it up + mark it as managed after we create the ms
  # resource.

  pacemaker_primitive drbd_primitive do
    agent "ocf:linbit:drbd"
    params drbd_params
    op rabbitmq_op
    # See big comment above as to why we do that. We know that the founder will
    # go first here, so we only do this on the founder.
    meta ({
      "is-managed" => "false"
    }) if (CrowbarPacemakerHelper.is_cluster_founder?(node) && ! ::Kernel.system("crm configure show #{drbd_primitive} &> /dev/null"))
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

  # See big comment above as to why we do that. We know that the founder will
  # go first here, so we only do this on the founder, but in short: this is
  # needed because we don't create all the pacemaker resources in the same
  # transaction.
  # Note that we don't use "crm resource manage" because it will change
  # is-managed of the ms resource...
  execute "Cleanup and manage #{drbd_primitive} on #{ms_name} start" do
    command "sleep 2; crm resource cleanup #{drbd_primitive}; crm_resource --resource #{drbd_primitive} --delete-parameter \"is-managed\" --meta || :"
    action :nothing
    subscribes :run, "pacemaker_ms[#{ms_name}]", :immediately
    only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end
end

pacemaker_primitive fs_primitive do
  agent "ocf:heartbeat:Filesystem"
  params fs_params
  op rabbitmq_op
  action :create
end

if node[:rabbitmq][:ha][:storage][:mode] == "drbd"
  pacemaker_colocation "col-#{fs_primitive}" do
    score "inf"
    resources [fs_primitive, "#{ms_name}:Master"]
    action :create
  end

  pacemaker_order "o-#{fs_primitive}" do
    score "Mandatory"
    ordering "#{ms_name}:promote #{fs_primitive}:start"
    # This is our last constraint, so we can finally start fs_primitive
    notifies :run, "execute[Cleanup #{fs_primitive} after constraints]", :immediately
    notifies :start, "pacemaker_primitive[#{fs_primitive}]", :immediately
  end

  # This is needed because we don't create all the pacemaker resources in the
  # same transaction, so we will need to cleanup before starting
  execute "Cleanup #{fs_primitive} after constraints" do
    command "sleep 2; crm resource cleanup #{fs_primitive}"
    action :nothing
  end
end

crowbar_pacemaker_sync_mark "create-rabbitmq_ha_storage"

# Ensure that uid/gid are the same on all nodes
#
# This is really hacky!!!
#
# We need to have the uid/gid be the same accross all nodes, but rabbitmq
# packages don't use a static uid/gid. So we pick one (91) which doesn't seem
# to be in use:
#  - see base-passwd package for Debian: http://sources.debian.net/src/base-passwd/3.5.32/passwd.master
#  - see wiki page for Fedora: https://fedoraproject.org/wiki/PackageUserRegistry
# We could use the chef user/group LWRP to do the change, but we also need to
# run other commands (to change ownership of existing files), so we might as
# well do a big script.
# We also stop rabbitmq in case it was running before, so we can change the uid
# without any impact. Pacemaker will start the process on one other node later
# on anyway.
static_uid = 91
static_gid = 91
bash "assign static uid to rabbitmq" do
 code <<EOC
 service rabbitmq-server stop > /dev/null;
 groupmod -g #{static_gid} rabbitmq;
 usermod -u #{static_uid} -g #{static_gid} rabbitmq;
 chown -R rabbitmq:rabbitmq /var/lib/rabbitmq;
 chown rabbitmq:rabbitmq /var/run/rabbitmq /var/log/rabbitmq;
 chown rabbitmq:rabbitmq /var/run/rabbitmq/pid /var/log/rabbitmq/*.log* || :;
EOC
 # Make any error in the commands fatal
 flags "-e"
 only_if "test \"$(id -u rabbitmq 2> /dev/null)\" != \"#{static_uid}\" -a \"$(id -g rabbitmq 2> /dev/null)\" != \"#{static_gid}\""
end

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

crowbar_pacemaker_sync_mark "sync-rabbitmq_before_ha"

crowbar_pacemaker_sync_mark "wait-rabbitmq_ha_resources"

# wait for DNS to be updated for hostname of virtual IP (otherwise, rabbitmq
# can't start)
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

pacemaker_primitive service_name do
  agent agent_name
  params ({
    "nodename" => node[:rabbitmq][:nodename],
  })
  op rabbitmq_op
  action :create
end

if node[:rabbitmq][:ha][:storage][:mode] == "drbd"

  pacemaker_colocation "col-#{service_name}" do
    score "inf"
    resources [fs_primitive, vip_primitive, service_name]
    action :create
  end

  pacemaker_order "o-#{service_name}" do
    score "Mandatory"
    ordering "#{fs_primitive} #{vip_primitive} #{service_name}"
    action :create
    # This is our last constraint, so we can finally start service_name
    notifies :run, "execute[Cleanup #{service_name} after constraints]", :immediately
    notifies :start, "pacemaker_primitive[#{service_name}]", :immediately
  end

  # This is needed because we don't create all the pacemaker resources in the
  # same transaction, so we will need to cleanup before starting
  execute "Cleanup #{service_name} after constraints" do
    command "sleep 2; crm resource cleanup #{service_name}"
    action :nothing
  end

else

  pacemaker_group group_name do
    # Membership order *is* significant; VIPs should come first so
    # that they are available for the service to bind to.
    members [fs_primitive, vip_primitive, service_name]
    action [ :create, :start ]
  end

end

crowbar_pacemaker_sync_mark "create-rabbitmq_ha_resources"

# wait for service to be active, to be sure there's no issue with pacemaker
# resources
ruby_block "wait for #{service_name} to be started" do
  block do
    require 'timeout'
    begin
      Timeout.timeout(30) do
        # Check that the service is running
        cmd = "crm resource show #{service_name} 2> /dev/null | grep -q \"is running on\""
        while ! ::Kernel.system(cmd)
          Chef::Log.debug("#{service_name} still not started")
          sleep(2)
        end
        # Check that the service is available, if it's running on this node
        cmd = "crm resource show #{service_name} | grep -q \" #{node.hostname} *$\""
        if ::Kernel.system(cmd)
          # The sed command grabs everything between '{running_applications'
          # and ']}', and what we want is that the rabbit application is
          # running
          cmd = "rabbitmqctl -q status 2> /dev/null| sed -n '/{running_applications/,/\]}/p' | grep -q '{rabbit,'"
          while ! ::Kernel.system(cmd)
            Chef::Log.debug("#{service_name} still not answering")
            sleep(2)
          end
        end
      end
    rescue Timeout::Error
      message = "The #{service_name} pacemaker resource is not started. Please manually check for an error."
      Chef::Log.fatal(message)
      raise message
    end
  end # block
end # ruby_block
