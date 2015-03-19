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

node[:cinder][:volumes].each_with_index do |volume, volid|
  unless volume[:backend_driver] == "rbd"
    next
  else

    ceph_conf = volume[:rbd][:config_file]
    admin_keyring = volume[:rbd][:admin_keyring]
    if File.exists?(admin_keyring)
      Chef::Log.info("Using external ceph cluster for cinder #{volume[:backend_name]} backend, with automatic setup.")
    else
      Chef::Log.info("Using external ceph cluster for cinder #{volume[:backend_name]} backend, with no automatic setup.")
      next
    end

    cmd = ["ceph", "-k", admin_keyring, "-c", ceph_conf, "-s"]
    check_ceph = Mixlib::ShellOut.new(cmd)

    unless check_ceph.run_command.stdout.match("(HEALTH_OK|HEALTH_WARN)")
      Chef::Log.info("Ceph cluster is not healthy; skipping the ceph setup for cinder #{volume[:backend_name]} backend")
      next
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
end

unless ceph_clients.empty?
  glance_servers = search(:node, "roles:glance-server")
  if glance_servers.length > 0
    glance_pool = glance_servers[0][:glance][:rbd][:store_pool]
  else
    glance_pool = nil
  end

  ceph_clients.each do |ceph_conf, ceph_pools|
    ceph_hash = Digest::MD5.hexdigest(ceph_conf)

    ceph_pools.each_pair do |cinder_user, cinder_pools|
      cinder_pools << glance_pool unless glance_pool.nil?

      allow_pools = cinder_pools.map{|p| "allow rwx pool=#{p}"}.join(", ")
      ceph_caps = { 'mon' => 'allow r', 'osd' => "allow class-read object_prefix rbd_children, #{allow_pools}" }

      # We have to compute MD5 hash from ceph_conf and cinder_user
      # to be sure that keyring file will not be overwritten 
      # by config from another cluster, with same user but different 
      # config file
      ceph_hash = Digest::MD5.hexdigest(ceph_conf)

      ceph_client cinder_user do
        ceph_conf  ceph_conf
        admin_keyring  ceph_keyrings[ceph_conf]
        caps ceph_caps
        keyname "client.#{ceph_hash}.#{cinder_user}"
        filename "/etc/ceph/ceph.client.#{ceph_hash}.#{cinder_user}.keyring"
        owner "root"
        group node[:cinder][:group]
        mode 0640
      end

    end
  end
end
