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
oscm_flavor_name = node[:oscm][:openstack][:flavor][:name]
oscm_flavor_ram = node[:oscm][:openstack][:flavor][:ram]
oscm_flavor_vcpus = node[:oscm][:openstack][:flavor][:vcpus]
oscm_flavor_disk = node[:oscm][:openstack][:flavor][:disk]
oscm_keypair_name = node[:oscm][:openstack][:keypair][:name]
oscm_keypair_publickey = node[:oscm][:openstack][:keypair][:publickey]
oscm_keypair_publickeyfile = node[:oscm][:openstack][:keypair][:publickeyfile]
oscm_heattemplate_path = node[:oscm][:openstack][:heattemplate_path]
oscm_volumestack_name = node[:oscm][:openstack][:volume_stack][:stack_name]
oscm_instancestack_name = node[:oscm][:openstack][:instance_stack][:stack_name]
oscm_db_volume_size = node[:oscm][:openstack][:volume_stack][:db_volume_size]
oscm_app_volume_size = node[:oscm][:openstack][:volume_stack][:app_volume_size]
oscm_image = node[:oscm][:openstack][:image]
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

bash "add oscm flavor and flavor access" do
  code <<-EOH
  nova flavor-create #{oscm_flavor_name} auto #{oscm_flavor_ram} #{oscm_flavor_disk} #{oscm_flavor_vcpus} --is-public false &> /dev/null || true
  tenant_id=$(openstack project show -f shell #{oscm_tenant} | grep -Po '(?<=^id=\")[^\"]*')
  nova flavor-access-add #{oscm_flavor_name} $tenant_id &> /dev/null || true
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

directory "#{oscm_heattemplate_path}" do
  owner oscm_group
  group oscm_group
  mode 0755
  recursive true
end

cookbook_file "#{oscm_heattemplate_path}/volumes.yaml" do
  source "volumes.yaml"
  owner oscm_group
  group oscm_group
  mode 0755
  action :create
end

cookbook_file "#{oscm_heattemplate_path}/application.yaml" do
  source "volumes.yaml"
  owner oscm_group
  group oscm_group
  mode 0755
  action :create
end

directory "#{oscm_heattemplate_path}/user-data" do
  owner oscm_group
  group oscm_group
  mode 0755
  recursive true
end

cookbook_file "#{oscm_heattemplate_path}/user-data/write-config" do
  source "user-data/write-config"
  owner oscm_group
  group oscm_group
  mode 0755
  action :create
end

cookbook_file "#{oscm_heattemplate_path}/user-data/deploy-oscmserver" do
  source "user-data/deploy-oscmserver"
  owner oscm_group
  group oscm_group
  mode 0755
  action :create
end

bash "create oscm stacks" do
  code <<-EOH
  openstack stack create --parameter "db_size=#{oscm_db_volume_size}" --parameter "app_size=#{oscm_app_volume_size}" -t #{oscm_heattemplate_path}/volumes.yaml #{oscm_volumestack_name} &> /dev/null || true
  app_volume_id=$(openstack stack output show -f shell #{oscm_volumestack_name} app_volume_id | grep -Po '(?<=^output_value=\")[^\"]*')
  db_volume_id=$(openstack stack output show -f shell #{oscm_volumestack_name} db_volume_id | grep -Po '(?<=^output_value=\")[^\"]*')
  openstack stack create --parameter "app_volume_id=${app_volume_id}" --parameter "db_volume_id=${db_volume_id}" --parameter "key_name=#{oscm_keypair_name}" --parameter "image=#{oscm_image}" -t #{oscm_heattemplate_path}/application.yaml #{oscm_instancestack_name} &> /dev/null || true
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

