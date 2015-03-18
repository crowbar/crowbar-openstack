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

glance_servers = search(:node, "roles:glance-server")
if glance_servers.length > 0
  glance_pool = glance_servers[0][:glance][:rbd][:store_pool]
else   
  glance_pool = nil
end

node[:cinder][:volumes].each_with_index do |volume, volid|
  if volume['backend_driver'] == "rbd"

    check_ceph = Mixlib::ShellOut.new("ceph -k #{volume['rbd']['admin_keyring']} -c #{volume['rbd']['config_file']} -s | grep -q -e 'HEALTH_[OK|WARN]'")
    check_ceph.run_command

    if check_ceph.exitstatus == 0

      backend_id = "backend-#{volume['backend_driver']}-#{volid}"
      cinder_user = volume[:rbd][:user]
      cinder_pool = volume[:rbd][:pool]

      cinder_pools = []
      cinder_pools << cinder_pool
      cinder_pools << glance_pool unless glance_pool.nil?
      allow_pools = cinder_pools.map{|p| "allow rwx pool=#{p}"}.join(", ")
      ceph_caps = { 'mon' => 'allow r', 'osd' => "allow class-read object_prefix rbd_children, #{allow_pools}" }

      ceph_client cinder_user do
        unless volume['rbd']['use_crowbar']
          ceph_conf  volume['rbd']['config_file']
          admin_keyring  volume['rbd']['admin_keyring']
        end
        caps ceph_caps
        keyname "client.#{cinder_user}"
        filename "/etc/ceph/ceph.client.#{cinder_user}.keyring"
        owner "root"
        group node[:cinder][:group]
        mode 0640
      end

      ceph_pool cinder_pool do
        unless volume['rbd']['use_crowbar']
          ceph_conf  volume['rbd']['config_file']
          admin_keyring  volume['rbd']['admin_keyring']
        end
        pool_name cinder_pool
      end

    end
  end
end
