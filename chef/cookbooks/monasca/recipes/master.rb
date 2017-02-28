#
# Copyright 2017 Fujitsu LIMITED
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
# limitation.

package "ansible"

keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)

directory "/opt/fujitsu" do
  owner "root"
  group "root"
  mode "0755"
end

# TODO: use package "monasca-installer"
remote_file "/opt/fujitsu/cmm-suse.tgz" do
  source node[:monasca][:master][:cmm_tarball_url]
  owner "root"
  group "root"
  mode "0644"
  action :create_if_missing
end

execute "extract cmm tarball" do
  command "tar xf cmm-suse.tgz"
  cwd "/opt/fujitsu/"
  not_if { Dir.exist?("/opt/fujitsu/monasca-installer") }
  notifies :run, "execute[run ansible]", :delayed
end

template "/opt/fujitsu/monasca-installer/credentials.yml" do
  source "credentials.yml.erb"
  owner "root"
  group "root"
  mode "0600"
  variables(
    keystone_settings: keystone_settings
  )
  notifies :run, "execute[run ansible]", :delayed
end

monasca_hosts = MonascaHelper.monasca_hosts(search(:node, "roles:monasca-server"))

raise "no nodes with monasca-server role found" if monasca_hosts.nil? or monasca_hosts.empty?

hosts_template =
  if monasca_hosts.length == 1
     "cmm-hosts-single.erb"
  else
    "cmm-hosts-cluster.erb"

template "/opt/fujitsu/monasca-installer/cmm-hosts" do
  source hosts_template
  owner "root"
  group "root"
  mode "0644"
  variables(
    monasca_host: monasca_hosts[0],
    monasca_hosts: monasca_hosts,
    ansible_ssh_user: "root",
    offline_resources_host: CrowbarHelper.get_host_for_admin_url(node),
    keystone_host: keystone_settings["public_url_host"]
  )
  notifies :run, "execute[run ansible]", :delayed
end

template "/opt/fujitsu/monasca-installer/group_vars/all_group" do
  source "all_group.erb"
  owner "root"
  group "root"
  mode "0644"
  variables(
    keystone_settings: keystone_settings
  )
  notifies :run, "execute[run ansible]", :delayed
end

# This file is used to mark that ansible installer run successfully.
# Without this, it could happen that the installer was not re-tried
# after a failed run.
file "/opt/fujitsu/monasca-installer/.installed" do
  content "cmm installed"
  owner "root"
  group "root"
  mode "0644"
  notifies :run, "execute[run ansible]", :delayed
  action :create_if_missing
end

execute "run ansible" do
  command "rm -f /opt/fujitsu/monasca-installer/.installed"\
          "&& ansible-playbook -i cmm-hosts monasca.yml"\
          "&& touch /opt/fujitsu/monasca-installer/.installed"
  cwd "/opt/fujitsu/monasca-installer"
  action :nothing
end
