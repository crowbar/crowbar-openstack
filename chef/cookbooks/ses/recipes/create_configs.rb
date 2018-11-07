#
# Cookbook Name:: create_configs
# Recipe:: crowbar
#
# Copyright 2018, SUSE Linux GmbH
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

def write_keyring_file(ses_config, service_name)
  Chef::Log.info("SES config write_keyring_file #{ses_config} for #{service_name}")
  client_name = ses_config[service_name]["rbd_store_user"]
  keyring_value = ses_config[service_name]["key"]
  Chef::Log.info("SES create #{service_name} keyring ceph.client.#{client_name}.keyring")
  template "/etc/ceph/client.ceph.#{client_name}.keyring" do
    source "client.keyring.erb"
    owner "cinder"
    group "root"
    mode "0644"
    variables(client_name: client_name,
              keyring_value: keyring_value)
  end
end

# This recipe creates the /etc/ceph/ceph.conf
# and the keyring files needed by the services
Chef::Log.info("SES: create_configs started")

ceph_conf  = search(:node, "ses:ceph_conf") || []
Chef::Log.info("SES: ceph_conf = #{ceph_conf}")

Chef::Log.info("SES config Try and load it!")
ses_config = BarclampLibrary::Barclamp::Config.load(
  "openstack",
  "ses"
)
Chef::Log.info("SES config = #{ses_config}")
Chef::Log.info("node = #{node}")
# This is an external ceph cluster, it could be SES
if !ses_config.nil? && !ses_config.empty?
  Chef::Log.info("Ceph is configred external and we found a SES proposal.")
  Chef::Log.info("SES create ceph.conf")
  # SES is enabled, lets create the ceph.conf
  template "/etc/ceph/ceph.conf" do
    source "ceph.conf.erb"
    owner "cinder"
    group "root"
    mode "0644"
    variables(fsid: ses_config["ceph_conf"]["fsid"],
              mon_initial_members: ses_config["ceph_conf"]["mon_initial_members"],
              mon_host: ses_config["ceph_conf"]["mon_host"],
              public_network: ses_config["ceph_conf"]["public_network"],
              cluster_network: ses_config["ceph_conf"]["cluster_network"],
              cinder_user: ses_config["cinder"]["rbd_store_user"],
              cinder_backup_user: ses_config["cinder_backup"]["rbd_store_user"],
              glance_user: ses_config["glance"]["rbd_store_user"])
  end

  # Now create the user keyring files
  write_keyring_file(ses_config, "cinder")
  write_keyring_file(ses_config, "cinder_backup")
  write_keyring_file(ses_config, "glance")
end

Chef::Log.info("SES: create_configs done")
