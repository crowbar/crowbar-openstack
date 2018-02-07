#
# Copyright 2016 SUSE
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

# https://docs.midonet.org/docs/latest-en/quick-start-guide/rhel-7_newton-rdo/content/_identity_service_keystone.html

keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)
register_auth_hash = { user: keystone_settings["admin_user"],
                       password: keystone_settings["admin_password"],
                       tenant: keystone_settings["admin_tenant"] }

# Configure keystone.
crowbar_pacemaker_sync_mark "wait-midonet_register"

keystone_register "register midonet service" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  service_name "midonet"
  service_type "midonet"
  service_description "MidoNet API Service"
  action :add_service
end

keystone_register "add midonet user" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  user_name node[:neutron][:midonet][:username]
  user_password keystone_settings["service_password"]
  tenant_name keystone_settings["service_tenant"]
  action :add_user
end

keystone_register "add admin role for midonet" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  user_name node[:neutron][:midonet][:username]
  tenant_name keystone_settings["service_tenant"]
  role_name "admin"
  action :add_access
end

crowbar_pacemaker_sync_mark "create-midonet_register"

template "/root/.midonetrc" do
  source "midonetrc.erb"
  owner "root"
  group "root"
  mode 0o640
  variables(
    midonet: node[:neutron][:midonet],
    keystone_settings: keystone_settings
  )
end

# Map NSDB nodes to neutron-server nodes. Eventually we could create a new
# role (nsdb-server).
zookeeper_hosts = node_search_with_cache("roles:neutron-server") || []
zookeeper_hosts = zookeeper_hosts.map(&:name)
Chef::Log.debug("zookeeper_hosts = #{zookeeper_hosts}")
zookeeper_host_list = zookeeper_hosts.join(",")
zookeeper_host_list_with_ports = zookeeper_hosts.map do |h|
  h + ":2181"
end
zookeeper_host_list_with_ports = zookeeper_host_list_with_ports.join(",")

template "/etc/midonet/midonet-mn.conf" do
  source "midonet-mn.conf.erb"
  owner "root"
  group "root"
  mode 0o640
  variables(
    zookeeper_host_list_with_ports: zookeeper_host_list_with_ports,
    zookeeper_host_list: zookeeper_host_list,
    replication_factor: zookeeper_hosts.length,
    keystone_settings: keystone_settings
  )
  notifies :start, "bash[configure-midonet]"
end

bash "configure-midonet" do
  code <<-CONF_MIDONET
       cat /etc/midonet/midonet-mn.conf | mn-conf set -t default
       touch /etc/midonet/midonet-configured
       CONF_MIDONET
  not_if do
    File.exist?("/etc/midonet/midonet-configured")
  end
  notifies :restart, "service[midonet-cluster]"
end

template "/etc/midonet/midonet.conf" do
  source "midonet.conf.erb"
  owner "root"
  group "root"
  mode 0o640
  variables(
    zookeeper_hosts: "#{zookeeper_host_list_with_ports}"
  )
  notifies :restart, "service[midonet-cluster]"
end

utils_systemd_environment "midonet-cluster" do
  service_name "midonet-cluster"
  environment node[:neutron][:midonet][:environment]
end

service "midonet-cluster" do
  supports status: true, restart: true
  action [:enable, :start]
end
