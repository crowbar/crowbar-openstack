#
# Copyright 2017, SUSE LINUX GmbH
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

oscm_tenant = node[:oscm][:keystone][:tenant]
oscm_user = node[:oscm][:keystone][:user]
oscm_password = node[:oscm][:keystone][:password]
oscm_flavor_name = node[:oscm][:openstack][:flavor_name]
oscm_flavor_ram = node[:oscm][:openstack][:flavor_ram]
oscm_flavor_vcpus = node[:oscm][:openstack][:flavor_vcpus]
oscm_flavor_disk = node[:oscm][:openstack][:flavor_disk]
oscm_keypair_name = node[:oscm][:openstack][:keypair]
oscm_keypair_publickey = node[:oscm][:openstack][:keypair_publickey]
oscm_keypair_publickeyfile = node[:oscm][:openstack][:keypair_publickeyfile]
oscm_group = "root"

keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)

register_auth_hash = {
  user: keystone_settings["admin_user"],
  password: keystone_settings["admin_password"],
  tenant: keystone_settings["admin_tenant"]
}

keystone_register "oscm wakeup keystone" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  action :wakeup
end

keystone_register "oscm create tenant" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  tenant_name oscm_tenant
  action :add_tenant
end

keystone_register "oscm register user" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  user_name oscm_user
  user_password oscm_password
  tenant_name oscm_tenant
  action :add_user
end

keystone_register "oscm give user admin role" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  user_name oscm_user
  tenant_name oscm_tenant
  role_name "admin"
  action :add_access
end

keystone_register "oscm give user member role" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  user_name oscm_user
  tenant_name oscm_tenant
  role_name "Member"
  action :add_access
end

keystone_register "oscm give user _member_ role" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  user_name oscm_user
  tenant_name oscm_tenant
  role_name "_member_"
  action :add_access
end

bash "add oscm flavor" do
  code <<-EOH
  nova flavor-create #{oscm_flavor_name} auto #{oscm_flavor_ram} #{oscm_flavor_disk} #{oscm_flavor_vcpus} --is-public false &> /dev/null || exit 0
EOH
  environment ({
    "OS_USERNAME" => oscm_user,
    "OS_PASSWORD" => oscm_password,
    "OS_TENANT_NAME" => oscm_tenant,
    "OS_AUTH_URL" => keystone_settings["internal_auth_url"],
    "OS_IDENTITY_API_VERSION" => keystone_settings["api_version"],
    "OS_USER_DOMAIN_NAME" => "Default",
    "OS_PROJECT_DOMAIN_NAME" => "Default"
  })
end

bash "add oscm keypair" do
  code <<-EOH
  publickey="#{oscm_keypair_publickey}"
  if !  -z  "${publickey// }"
  then
    mkdir -p "$(dirname "#{oscm_keypair_publickeyfile}")" &> /dev/null
    echo "${publickey}" > "#{oscm_keypair_publickeyfile}"
    nova keypair-add #{oscm_keypair_name} --pub-key #{oscm_keypair_publickeyfile} &> /dev/null || exit 0
  fi
EOH
  environment ({
    "OS_USERNAME" => oscm_user,
    "OS_PASSWORD" => oscm_password,
    "OS_TENANT_NAME" => oscm_tenant,
    "OS_AUTH_URL" => keystone_settings["internal_auth_url"],
    "OS_IDENTITY_API_VERSION" => keystone_settings["api_version"],
    "OS_USER_DOMAIN_NAME" => "Default",
    "OS_PROJECT_DOMAIN_NAME" => "Default"
  })
end

if node[:oscm][:api][:protocol] == "https"
  ssl_setup "setting up ssl for oscm" do
    generate_certs node[:oscm][:ssl][:generate_certs]
    certfile node[:oscm][:ssl][:certfile]
    keyfile node[:oscm][:ssl][:keyfile]
    group oscm_group
    fqdn node[:fqdn]
    ca_certs node[:oscm][:ssl][:ca_certs]
  end
end

%w[ /etc /etc/oscm /etc/oscm/heat ].each do |path|
  directory path do
    owner 'root'
    group 'root'
    mode '0755'
  end

cookbook_file '/etc/oscm/heat/volumes.yaml' do
  source 'volumes.yaml'
  owner 'root'
  group 'root'
  mode '0755'
  action :create
end