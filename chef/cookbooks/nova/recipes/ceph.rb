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
# This is the first of a 2 part set of scripts to ensure that ceph support
# is added to nova/libvirt.  This part ensures that the ceph config files
# and keyrings are in place.  The 2nd part is run after libvirtd has been
# installed and started, so the virsh secrets can be installed.

# Cookbook Name:: nova
# Recipe:: ceph
#

has_internal = false
has_external = false

cinder_controller = node_search_with_cache("roles:cinder-controller").first
return if cinder_controller.nil?

# First loop to find if we have internal/external cluster
cinder_controller[:cinder][:volumes].each_with_index do |volume, volid|
  next unless volume[:backend_driver] == "rbd"

  has_internal ||= true if volume[:rbd][:use_crowbar]
  has_external ||= true unless volume[:rbd][:use_crowbar]
end

if has_internal
  ceph_env_filter = " AND ceph_config_environment:ceph-config-default"
  ceph_servers = search(:node, "roles:ceph-osd#{ceph_env_filter}") || []
  if ceph_servers.length > 0
    include_recipe "ceph::keyring"
  else
    message = "Ceph was not deployed with Crowbar yet!"
    Chef::Log.fatal(message)
    raise message
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

  # call the SES recipe to create the ceph.conf and keyrings
  Chef::Log.info("Calling SES to create configs")
  node.run_state["ses_service"] = "nova"
  include_recipe "ses::create_configs"
end

# Second loop to do our setup
cinder_controller[:cinder][:volumes].each_with_index do |volume, volid|
  next unless volume[:backend_driver] == "rbd"

  rbd_user = volume[:rbd][:user]
  rbd_uuid = volume[:rbd][:secret_uuid]

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
      cmd = ["ceph", "--id", rbd_user, "-c", ceph_conf, "-s"]
      Chef::Log.info("Check ceph -s with #{cmd}")
      check_ceph = Mixlib::ShellOut.new(cmd)

      unless check_ceph.run_command.stdout.match("(HEALTH_OK|HEALTH_WARN)")
        Chef::Log.info("Ceph cluster is not healthy; Nova skipping the ceph setup for backend #{volume[:backend_name]}")
        next
      end
    else
      # Check if rbd keyring was uploaded manually by user
      client_keyring = "/etc/ceph/ceph.client.#{rbd_user}.keyring"
      unless File.exist?(client_keyring)
        Chef::Log.info("Ceph user keyring wasn't provided for backend #{volume[:backend_name]}")
        next
      end
    end
  end
end
