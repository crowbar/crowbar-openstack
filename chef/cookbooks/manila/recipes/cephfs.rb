#
# Copyright (c) 2016 SUSE Linux GmbH.
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
# Cookbook Name:: manila
# Recipe:: cephfs
#

package "ceph-common"

if ManilaHelper.has_cephfs_internal_cluster? node
  # use a crowbar deployed ceph cluster
  Chef::Log.info("Using internal ceph cluster for Manila.")

  ceph_conf = "/etc/ceph/ceph.conf"
  admin_keyring = "/etc/ceph/ceph.client.admin.keyring"
  ceph_user = "manila"
  # see http://docs.openstack.org/developer/manila/devref/cephfs_native_driver.html#authorize-the-driver-to-communicate-with-ceph
  ceph_caps = {
    "mds" => "allow *",
    "osd" => "allow rw",
    "mon" => "allow r, allow command \"auth del\", allow command \"auth caps\", allow command \"auth get\", allow command \"auth get-or-create\"",
  }

  ceph_client ceph_user do
    ceph_conf ceph_conf
    admin_keyring admin_keyring
    caps ceph_caps
    keyname "client.#{ceph_user}"
    filename "/etc/ceph/ceph.client.#{ceph_user}.keyring"
    owner "root"
    group node[:manila][:group]
    mode 0640
  end
end
