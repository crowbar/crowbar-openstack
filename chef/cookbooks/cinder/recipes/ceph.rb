#
# Copyright (c) 2015 SUSE Linux GmbH.
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
# Cookbook Name:: cinder
# Recipe:: ceph
#

ceph_clients = {}
ceph_keyrings = {}

has_internal = false
has_external = false

# First loop to find if we have internal/external cluster
node[:cinder][:volumes].each_with_index do |volume, volid|
  next unless volume[:backend_driver] == "rbd"

  has_internal ||= true if volume[:rbd][:use_crowbar]
  has_external ||= true unless volume[:rbd][:use_crowbar]
end

if has_internal
  ceph_env_filter = " AND ceph_config_environment:ceph-config-default"
  ceph_servers = search(:node, "run_list_map:ceph-osd#{ceph_env_filter}") || []
  if ceph_servers.length > 0
    include_recipe "ceph::keyring"
  else
    # If we don't have any osd from our query, it could be because the
    # osd nodes temporarily lost the role (while rebooting, for instance).
    # So check if the ceph setup was done once already, to decide whether
    # to fail or just to emit a warning.
    if File.exist?("/etc/ceph/ceph.client.admin.keyring")
      Chef::Log.warn("Ceph nodes seem to not be running; RBD backends might not work.")
    else
      message = "Ceph was not deployed with Crowbar yet!"
      Chef::Log.fatal(message)
      raise message
    end
  end
end

if has_external
  # Ensure ceph is available here
  if node[:platform_family] == "suse"
    # install package in compile phase because we will run "ceph -s"
    package "ceph-common" do
      action :nothing
    end.run_action(:install)
  end
end

# Second loop to do our setup
node[:cinder][:volumes].each_with_index do |volume, volid|
  next unless volume[:backend_driver] == "rbd"

  if volume[:rbd][:use_crowbar]
    ceph_conf = "/etc/ceph/ceph.conf"
    admin_keyring = "/etc/ceph/ceph.client.admin.keyring"
  else
    ceph_conf = volume[:rbd][:config_file]
    admin_keyring = volume[:rbd][:admin_keyring]

    if ceph_conf.empty? || !File.exist?(ceph_conf)
      Chef::Log.info("Ceph configuration file is missing; skipping the ceph setup for backend #{volume[:backend_name]}")
      next
    end

    if !admin_keyring.empty? && File.exist?(admin_keyring)
      Chef::Log.info("Using external ceph cluster for cinder #{volume[:backend_name]} backend, with automatic setup.")
    else
      Chef::Log.info("Using external ceph cluster for cinder #{volume[:backend_name]} backend, with no automatic setup.")
      next
    end

    cmd = ["ceph", "-k", admin_keyring, "-c", ceph_conf, "-s"]
    check_ceph = Mixlib::ShellOut.new(cmd)

    unless check_ceph.run_command.stdout.match("(HEALTH_OK|HEALTH_WARN)")
      Chef::Log.info("Ceph cluster is not healthy; skipping the ceph setup for backend #{volume[:backend_name]}")
      next
    end
  end

  backend_id = "backend-#{volume[:backend_driver]}-#{volid}"

  cinder_user = volume[:rbd][:user]
  cinder_pool = volume[:rbd][:pool]

  ceph_clients[ceph_conf] = {} unless ceph_clients[ceph_conf]
  ceph_keyrings[ceph_conf] = admin_keyring unless ceph_keyrings[ceph_conf]

  cinder_pools = (ceph_clients[ceph_conf][cinder_user] || []) << cinder_pool
  ceph_clients[ceph_conf][cinder_user] = cinder_pools

  ceph_pool cinder_pool do
    ceph_conf ceph_conf
    admin_keyring admin_keyring
  end
end

unless ceph_clients.empty?
  glance_servers = search(:node, "roles:glance-server")
  if glance_servers.length > 0
    glance_pool = glance_servers[0][:glance][:rbd][:store_pool]
  else
    glance_pool = nil
  end

  ceph_clients.each do |ceph_conf, ceph_pools|
    ceph_pools.each_pair do |cinder_user, cinder_pools|

      allow_pools = cinder_pools.map{ |p| "allow rwx pool=#{p}" }.join(", ")
      allow_pools += ", allow rx pool=#{glance_pool}" if glance_pool
      ceph_caps = { "mon" => "allow r", "osd" => "allow class-read object_prefix rbd_children, #{allow_pools}" }

      ceph_client cinder_user do
        ceph_conf ceph_conf
        admin_keyring ceph_keyrings[ceph_conf]
        caps ceph_caps
        keyname "client.#{cinder_user}"
        filename "/etc/ceph/ceph.client.#{cinder_user}.keyring"
        owner "root"
        group node[:cinder][:group]
        mode 0640
      end
    end
  end
end
