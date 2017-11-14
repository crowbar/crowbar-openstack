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

escm_project = node[:escm][:keystone][:project]
escm_user = node[:escm][:keystone][:user]
escm_password = node[:escm][:keystone][:password]
escm_ssl_certfile = node[:escm][:ssl][:certfile]
escm_ssl_keyfile = node[:escm][:ssl][:keyfile]
escm_ssl_cacerts = node[:escm][:ssl][:ca_certs]
escm_flavor_name = node[:escm][:openstack][:flavor][:name]
escm_flavor_ram = node[:escm][:openstack][:flavor][:ram]
escm_flavor_vcpus = node[:escm][:openstack][:flavor][:vcpus]
escm_flavor_disk = node[:escm][:openstack][:flavor][:disk]
escm_keypair_name = node[:escm][:openstack][:keypair][:name]
escm_keypair_publickey = node[:escm][:openstack][:keypair][:publickey]
escm_keypair_publickeyfile = "/etc/escm/install/openstack_keypair_public.pem"
escm_install_path = "/etc/escm/install"
escm_path = "/etc/escm"
escm_volumestack_name = node[:escm][:openstack][:volume_stack][:stack_name]
escm_instancestack_name = node[:escm][:openstack][:instance_stack][:stack_name]
escm_data_volume_size = node[:escm][:openstack][:volume_stack][:data_volume_size]
escm_logs_volume_size = node[:escm][:openstack][:volume_stack][:logs_volume_size]
escm_image = node[:escm][:openstack][:image]
escm_floating_network = node[:escm][:openstack][:floating_network]
escm_keypair_crowbar_sshkey = "/etc/escm/install/escm_ssh.key"
escm_group = "root"

keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)

env = "OS_USERNAME='#{escm_user}' "
env << "OS_PASSWORD='#{escm_password}' "
env << "OS_PROJECT_NAME='#{escm_project}' "
env << "OS_AUTH_URL='#{keystone_settings["internal_auth_url"]}' "
env << "OS_INTERFACE=internal "
env << "OS_IDENTITY_API_VERSION='#{keystone_settings["api_version"]}' "
env << "OS_USER_DOMAIN_NAME='Default' "
env << "OS_PROJECT_DOMAIN_NAME='Default'"

openstack_cmd = "#{env} openstack"

openstack_args_keystone = keystone_settings["insecure"] ? "--insecure" : ""

nova_config = Barclamp::Config.load("openstack", "nova", node[:escm][:nova_instance])
nova_insecure = CrowbarOpenStackHelper.insecure(nova_config)
openstack_args_nova = nova_insecure || keystone_settings["insecure"] ? "--insecure" : ""

heat_config = Barclamp::Config.load("openstack", "heat", node[:escm][:heat_instance])
heat_insecure = CrowbarOpenStackHelper.insecure(heat_config)
openstack_args_heat = heat_insecure || keystone_settings["insecure"] ? "--insecure" : ""

register_auth_hash = {
  user: keystone_settings["admin_user"],
  password: keystone_settings["admin_password"],
  tenant: keystone_settings["admin_tenant"]
}

keystone_register "escm wakeup keystone" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  action :wakeup
end

keystone_register "escm create project" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  tenant_name escm_project
  action :add_tenant
end

keystone_register "escm register user" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  user_name escm_user
  user_password escm_password
  tenant_name escm_project
  action :add_user
end

keystone_register "escm give user admin role" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  user_name escm_user
  tenant_name escm_project
  role_name "admin"
  action :add_access
end

keystone_register "escm give user member role" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  user_name escm_user
  tenant_name escm_project
  role_name "Member"
  action :add_access
end

keystone_register "escm give user _member_ role" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  user_name escm_user
  tenant_name escm_project
  role_name "_member_"
  action :add_access
end

ruby_block "check_escm_glance_image" do
    block do
      Chef::Resource::RubyBlock.send(:include, Chef::Mixin::ShellOut)
      command = "#{openstack_cmd} #{openstack_args_heat} image list -c Name -f value | egrep '^#{escm_image}$'"
      command_out = shell_out(command)
      if command_out.stdout.strip != escm_image
        message = "The image with name '#{escm_image}' is not found in glance! Please check your escm proposal attributes or glance image registry."
        raise message         
      end
    end
    action :create
end

execute "create_escm_flavor" do
  command "#{openstack_cmd} #{openstack_args_nova} flavor create --ram #{escm_flavor_ram} --disk #{escm_flavor_disk} \
  --vcpus #{escm_flavor_vcpus} --private #{escm_flavor_name}"
  not_if "#{openstack_cmd} #{openstack_args_nova} flavor list --all -c Name -f value | egrep -q '^#{escm_flavor_name}$'"
end

execute "create_escm_flavor_access" do
  command "#{openstack_cmd} #{openstack_args_nova} flavor set --project #{escm_project} #{escm_flavor_name}"
  ignore_failure true
end

bash "create_escm_keypair_file" do
  code <<-EOH
  publickey="#{escm_keypair_publickey}"
  mkdir -p $(dirname #{escm_keypair_publickeyfile})
  echo "${publickey}" > "#{escm_keypair_publickeyfile}"
EOH
end

execute "create_escm_keypair" do
  command "#{openstack_cmd} #{openstack_args_nova} keypair create #{escm_keypair_name} --public-key #{escm_keypair_publickeyfile}"
  not_if "#{openstack_cmd} #{openstack_args_nova} keypair list -c Name -f value | egrep -q '^#{escm_keypair_name}$'"
end

directory "#{escm_install_path}" do
  owner escm_group
  group escm_group
  mode 0640
  recursive true
end

cookbook_file "#{escm_install_path}/volumes.yaml" do
  source "volumes.yaml"
  owner escm_group
  group escm_group
  mode 0640
  action :create
end

cookbook_file "#{escm_install_path}/application.yaml" do
  source "application.yaml"
  owner escm_group
  group escm_group
  mode 0640
  action :create
end

directory "#{escm_install_path}/user-data" do
  owner escm_group
  group escm_group
  mode 0640
  recursive true
end

cookbook_file "#{escm_install_path}/user-data/heat-config" do
  source "user-data/heat-config"
  owner escm_group
  group escm_group
  mode 0640
  action :create
end

cookbook_file "#{escm_install_path}/user-data/deploy-escmserver" do
  source "user-data/deploy-escmserver"
  owner escm_group
  group escm_group
  mode 0640
  action :create
end

execute "create_escm_volume_stack" do
  command "#{openstack_cmd} #{openstack_args_heat} stack create --parameter data_size=#{escm_data_volume_size} --parameter logs_size=#{escm_logs_volume_size} \
  -t #{escm_install_path}/volumes.yaml --wait #{escm_volumestack_name}"
  not_if "#{openstack_cmd} #{openstack_args_heat} stack list -c 'Stack Name' -f value | egrep -q '^#{escm_volumestack_name}$'"
end

ruby_block "get_escm_volume_ids" do
    block do
      Chef::Resource::RubyBlock.send(:include, Chef::Mixin::ShellOut)
      command = "#{openstack_cmd} #{openstack_args_heat} stack output show -f shell #{escm_volumestack_name} data_volume_id | grep -Po '(?<=^output_value=\")[^\"]*'"
      command_out = shell_out(command)
      node[:escm][:openstack][:volume_stack][:data_volume_id] = command_out.stdout.strip
      command = "#{openstack_cmd} #{openstack_args_heat} stack output show -f shell #{escm_volumestack_name} logs_volume_id | grep -Po '(?<=^output_value=\")[^\"]*'"
      command_out = shell_out(command)
      node[:escm][:openstack][:volume_stack][:logs_volume_id] = command_out.stdout.strip
    end
    action :create
end

ruby_block "generate_escm_crowbar_ssh_keys" do
    block do
      Chef::Resource::RubyBlock.send(:include, Chef::Mixin::ShellOut)
      command = "mkdir -p '$(dirname #{escm_keypair_crowbar_sshkey})'"
      command_out = shell_out(command)
      command = "[ ! -f #{escm_keypair_crowbar_sshkey} ] && yes y | ssh-keygen -t rsa -f #{escm_keypair_crowbar_sshkey} -N ''"
      command_out = shell_out(command)
    end
    action :create
end

execute "create_escm_instance_stack" do
  command lazy { "#{openstack_cmd} #{openstack_args_heat} stack create --parameter logs_volume_id=#{node[:escm][:openstack][:volume_stack][:logs_volume_id]} \
  --parameter data_volume_id=#{node[:escm][:openstack][:volume_stack][:data_volume_id]} \
  --parameter image=#{escm_image} --parameter flavor=#{escm_flavor_name} \
  --parameter key_name=#{escm_keypair_name} --parameter floating_network=#{escm_floating_network} \
  --parameter-file ssh_cert=#{escm_keypair_crowbar_sshkey}.pub \
  -t #{escm_install_path}/application.yaml --wait #{escm_instancestack_name}" }
  not_if "#{openstack_cmd} #{openstack_args_heat} stack list -c 'Stack Name' -f value | egrep -q '^#{escm_instancestack_name}$'"
end

ruby_block "get_escm_floating_ip" do
    block do
      Chef::Resource::RubyBlock.send(:include, Chef::Mixin::ShellOut)
      command = "#{openstack_cmd} #{openstack_args_heat} stack output show -f shell --variable output_value #{escm_instancestack_name} ip_appserver | grep -Po '(?<=^output_value=\")[^\"]*'"
      command_out = shell_out(command)
      node[:escm][:openstack][:instance_stack][:ip_appserver] = command_out.stdout.strip
    end
    action :create
end

if node[:escm][:api][:protocol] == "https"
  ssl_setup "setting up ssl for escm" do
    generate_certs node[:escm][:ssl][:generate_certs]
    certfile node[:escm][:ssl][:certfile]
    keyfile node[:escm][:ssl][:keyfile]
    group escm_group
    fqdn lazy { node[:escm][:ssl][:fqdn].empty? ? node[:escm][:openstack][:instance_stack][:ip_appserver] : node[:escm][:ssl][:fqdn] }
    ca_certs node[:escm][:ssl][:ca_certs]
  end
end

ruby_block "get_escm_secrets" do
    block do
      Chef::Resource::RubyBlock.send(:include, Chef::Mixin::ShellOut)
      command = "#{openstack_cmd} #{openstack_args_heat} stack output show -f shell --variable output_value #{escm_instancestack_name} db_password | grep -Po '(?<=^output_value=\")[^\"]*'"
      command_out = shell_out(command)
      node[:escm][:openstack][:instance_stack][:db_password] = command_out.stdout.strip
      command = "#{openstack_cmd} #{openstack_args_heat} stack output show -f shell --variable output_value #{escm_instancestack_name} db_core_password | grep -Po '(?<=^output_value=\")[^\"]*'"
      command_out = shell_out(command)
      node[:escm][:openstack][:instance_stack][:db_core_password] = command_out.stdout.strip
      command = "#{openstack_cmd} #{openstack_args_heat} stack output show -f shell --variable output_value #{escm_instancestack_name} db_app_password | grep -Po '(?<=^output_value=\")[^\"]*'"
      command_out = shell_out(command)
      node[:escm][:openstack][:instance_stack][:db_app_password] = command_out.stdout.strip
      command = "#{openstack_cmd} #{openstack_args_heat} stack output show -f shell --variable output_value #{escm_instancestack_name} key_secret | grep -Po '(?<=^output_value=\")[^\"]*'"
      command_out = shell_out(command)
      node[:escm][:openstack][:instance_stack][:key_secret] = command_out.stdout.strip
    end
    action :create
end

var_no_proxy = node[:escm][:proxy][:no_proxy].empty? ? "#{node[:escm][:proxy][:no_proxy_default]},#{node[:escm][:openstack][:instance_stack][:ip_appserver]}" : "#{node[:escm][:proxy][:no_proxy_default]},#{node[:escm][:openstack][:instance_stack][:ip_appserver]},#{node[:escm][:proxy][:no_proxy]}"
var_key_secret = "#{node[:escm][:openstack][:instance_stack][:key_secret]}"
var_host_fqdn = node[:escm][:ssl][:fqdn].empty? ? "#{node[:escm][:openstack][:instance_stack][:ip_appserver]}" : "#{node[:escm][:ssl][:fqdn]}"
var_db_pwd_core = "#{node[:escm][:openstack][:instance_stack][:db_core_password]}"
var_db_pwd_app = "#{node[:escm][:openstack][:instance_stack][:db_app_password]}"
var_db_superpwd = "#{node[:escm][:openstack][:instance_stack][:db_password]}"

template "#{escm_install_path}/var.env" do
  source "var.env.erb"
  owner escm_group
  group escm_group
  mode 0640
  variables(
    mail: node[:escm][:mail],
    docker: node[:escm][:docker],
    proxy: node[:escm][:proxy],
    no_proxy: var_no_proxy,
    key_secret: var_key_secret,
    host_fqdn: var_host_fqdn,
    db_pwd_core: var_db_pwd_core,
    db_pwd_app: var_db_pwd_app,
    db_superpwd: var_db_superpwd
  )
end

template "#{escm_install_path}/.env" do
  source ".env.erb"
  owner escm_group
  group escm_group
  mode 0640
    variables(
      docker: node[:escm][:docker]
    )
end

ruby_block "inject_escm_scripts" do
    block do
      args = "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i #{escm_keypair_crowbar_sshkey}"
      ip_appserver = node[:escm][:openstack][:instance_stack][:ip_appserver]
      Chef::Resource::RubyBlock.send(:include, Chef::Mixin::ShellOut)
      command = "ssh #{args} #{ip_appserver} 'mkdir -p #{escm_path}/docker-compose'"
      command_out = shell_out(command)
      command = "scp #{args} #{escm_install_path}/var.env #{ip_appserver}:#{escm_path}/docker-compose"
      command_out = shell_out(command)
      command = "scp #{args} #{escm_install_path}/.env #{ip_appserver}:#{escm_path}/docker-compose"
      command_out = shell_out(command)
      if node[:escm][:api][:protocol] == "https"
        command = "ssh #{args} #{ip_appserver} 'mkdir -p #{escm_path}/ssl'"
        command_out = shell_out(command)
        command = "scp #{args} #{escm_ssl_certfile} #{ip_appserver}:#{escm_path}/ssl/escm.crt"
        command_out = shell_out(command)
        command = "scp #{args} #{escm_ssl_keyfile} #{ip_appserver}:#{escm_path}/ssl/escm.key"
        command_out = shell_out(command)
        command = "scp #{args} #{escm_ssl_cacerts} #{ip_appserver}:#{escm_path}/ssl/escm.chain"
      end
      command = "scp #{args} #{escm_install_path}/user-data/deploy-escmserver #{ip_appserver}:#{escm_path}/config/"
      command_out = shell_out(command)
      command = "ssh #{args} #{ip_appserver} 'chmod 755 #{escm_path}/config/deploy-escmserver'"
      command_out = shell_out(command)
      command = "ssh #{args} #{ip_appserver} '#{escm_path}/config/deploy-escmserver' &"
      command_out = shell_out(command)
    end
    action :create
end
