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

oscm_project = node[:oscm][:keystone][:project]
oscm_user = node[:oscm][:keystone][:user]
oscm_password = node[:oscm][:keystone][:password]
oscm_ssl_certfile = node[:oscm][:ssl][:certfile]
oscm_ssl_keyfile = node[:oscm][:ssl][:keyfile]
oscm_ssl_cacerts = node[:oscm][:ssl][:ca_certs]
oscm_flavor_name = node[:oscm][:openstack][:flavor][:name]
oscm_flavor_ram = node[:oscm][:openstack][:flavor][:ram]
oscm_flavor_vcpus = node[:oscm][:openstack][:flavor][:vcpus]
oscm_flavor_disk = node[:oscm][:openstack][:flavor][:disk]
oscm_keypair_name = node[:oscm][:openstack][:keypair][:name]
oscm_keypair_publickey = node[:oscm][:openstack][:keypair][:publickey]
oscm_keypair_publickeyfile = "/etc/oscm/install/openstack_keypair_public.pem"
oscm_install_path = "/etc/oscm/install"
oscm_config_path = "/etc/oscm/config"
oscm_volumestack_name = node[:oscm][:openstack][:volume_stack][:stack_name]
oscm_instancestack_name = node[:oscm][:openstack][:instance_stack][:stack_name]
oscm_db_volume_size = node[:oscm][:openstack][:volume_stack][:db_volume_size]
oscm_app_volume_size = node[:oscm][:openstack][:volume_stack][:app_volume_size]
oscm_image = node[:oscm][:openstack][:image]
oscm_docker_host = node[:oscm][:docker][:host]
oscm_docker_port = node[:oscm][:docker][:port]
oscm_docker_user = node[:oscm][:docker][:user]
oscm_docker_pwd = node[:oscm][:docker][:password]
oscm_docker_tag = node[:oscm][:docker][:tag]
oscm_proxy_httphost = node[:oscm][:proxy][:http_host]
oscm_proxy_httpport = node[:oscm][:proxy][:http_port]
oscm_proxy_httpshost = node[:oscm][:proxy][:https_host]
oscm_proxy_httpsport = node[:oscm][:proxy][:https_port]
oscm_proxy_user = node[:oscm][:proxy][:user]
oscm_proxy_pwd = node[:oscm][:proxy][:password]
oscm_mail_host = node[:oscm][:mail][:host]
oscm_mail_port = node[:oscm][:mail][:port]
oscm_mail_tls = node[:oscm][:mail][:tls]
oscm_mail_from = node[:oscm][:mail][:from]
oscm_mail_auth = node[:oscm][:mail][:auth]
oscm_mail_user = node[:oscm][:mail][:user]
oscm_mail_pwd = node[:oscm][:mail][:password]
oscm_keypair_crowbar_sshkey = "/etc/oscm/install/oscm_ssh.key"
oscm_group = "root"

keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)

env = "OS_USERNAME='#{oscm_user}' "
env << "OS_PASSWORD='#{oscm_password}' "
env << "OS_PROJECT_NAME='#{oscm_project}' "
env << "OS_AUTH_URL='#{keystone_settings["internal_auth_url"]}' "
env << "OS_INTERFACE=internal "
env << "OS_IDENTITY_API_VERSION='#{keystone_settings["api_version"]}' "
env << "OS_USER_DOMAIN_NAME='Default' "
env << "OS_PROJECT_DOMAIN_NAME='Default'"

openstack_cmd = "#{env} openstack"

openstack_args_keystone = keystone_settings["insecure"] ? "--insecure" : ""

nova_config = Barclamp::Config.load("openstack", "nova", node[:oscm][:nova_instance])
nova_insecure = CrowbarOpenStackHelper.insecure(nova_config)
openstack_args_nova = nova_insecure || keystone_settings["insecure"] ? "--insecure" : ""

heat_config = Barclamp::Config.load("openstack", "heat", node[:oscm][:heat_instance])
heat_insecure = CrowbarOpenStackHelper.insecure(heat_config)
openstack_args_heat = heat_insecure || keystone_settings["insecure"] ? "--insecure" : ""

ruby_block "check_oscm_glance_image" do
    block do
      Chef::Resource::RubyBlock.send(:include, Chef::Mixin::ShellOut)
      command = "#{openstack_cmd} #{openstack_args_heat} image list -c Name -f value | egrep '^#{oscm_image}$'"
      command_out = shell_out(command)
      if command_out.stdout.strip != oscm_image
        message = "The image with name '#{oscm_image}' is not found in glance! Please check your oscm proposal attributes or glance image registry."
        raise message         
      end
    end
    action :create
end


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

keystone_register "oscm create project" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  tenant_name oscm_project
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
  tenant_name oscm_project
  action :add_user
end

keystone_register "oscm give user admin role" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  user_name oscm_user
  tenant_name oscm_project
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
  tenant_name oscm_project
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
  tenant_name oscm_project
  role_name "_member_"
  action :add_access
end

execute "create_oscm_flavor" do
  command "#{openstack_cmd} #{openstack_args_nova} flavor create --ram #{oscm_flavor_ram} --disk #{oscm_flavor_disk} \
  --vcpus #{oscm_flavor_vcpus} --private #{oscm_flavor_name}"
  not_if "#{openstack_cmd} #{openstack_args_nova} flavor list --all -c Name -f value | egrep -q '^#{oscm_flavor_name}$'"
end

execute "create_oscm_flavor_access" do
  command "#{openstack_cmd} #{openstack_args_nova} flavor set --project #{oscm_project} #{oscm_flavor_name}"
  ignore_failure true
end

bash "create_oscm_keypair_file" do
  code <<-EOH
  publickey="#{oscm_keypair_publickey}"
  mkdir -p "$(dirname "#{oscm_keypair_publickeyfile}")" &> /dev/null
  echo "${publickey}" > "#{oscm_keypair_publickeyfile}"
EOH
end

execute "create_oscm_keypair" do
  command "#{openstack_cmd} #{openstack_args_nova} keypair create #{oscm_keypair_name} --public-key #{oscm_keypair_publickeyfile}"
  not_if "#{openstack_cmd} #{openstack_args_nova} keypair list -c Name -f value | egrep -q '^#{oscm_keypair_name}$'"
end

directory "#{oscm_install_path}" do
  owner oscm_group
  group oscm_group
  mode 0640
  recursive true
end

cookbook_file "#{oscm_install_path}/volumes.yaml" do
  source "volumes.yaml"
  owner oscm_group
  group oscm_group
  mode 0640
  action :create
end

cookbook_file "#{oscm_install_path}/application.yaml" do
  source "application.yaml"
  owner oscm_group
  group oscm_group
  mode 0640
  action :create
end

directory "#{oscm_install_path}/user-data" do
  owner oscm_group
  group oscm_group
  mode 0640
  recursive true
end

cookbook_file "#{oscm_install_path}/user-data/heat-config" do
  source "user-data/heat-config"
  owner oscm_group
  group oscm_group
  mode 0640
  action :create
end

cookbook_file "#{oscm_install_path}/user-data/deploy-oscmserver" do
  source "user-data/deploy-oscmserver"
  owner oscm_group
  group oscm_group
  mode 0640
  action :create
end

execute "create_oscm_volume_stack" do
  command "#{openstack_cmd} #{openstack_args_heat} stack create --parameter db_size=#{oscm_db_volume_size} --parameter app_size=#{oscm_app_volume_size} \
  -t #{oscm_install_path}/volumes.yaml --wait #{oscm_volumestack_name}"
  not_if "#{openstack_cmd} #{openstack_args_heat} stack list -c 'Stack Name' -f value | egrep -q '^#{oscm_volumestack_name}$'"
end

ruby_block "get_oscm_volume_ids" do
    block do
      Chef::Resource::RubyBlock.send(:include, Chef::Mixin::ShellOut)
      command = "#{openstack_cmd} #{openstack_args_heat} stack output show -f shell #{oscm_volumestack_name} db_volume_id | grep -Po '(?<=^output_value=\")[^\"]*'"
      command_out = shell_out(command)
      node[:oscm][:openstack][:volume_stack][:db_volume_id] = command_out.stdout.strip
      command = "#{openstack_cmd} #{openstack_args_heat} stack output show -f shell #{oscm_volumestack_name} app_volume_id | grep -Po '(?<=^output_value=\")[^\"]*'"
      command_out = shell_out(command)
      node[:oscm][:openstack][:volume_stack][:app_volume_id] = command_out.stdout.strip
    end
    action :create
end

ruby_block "generate_oscm_crowbar_ssh_keys" do
    block do
      Chef::Resource::RubyBlock.send(:include, Chef::Mixin::ShellOut)
      command = "mkdir -p '$(dirname #{oscm_keypair_crowbar_sshkey})'"
      command_out = shell_out(command)
      command = "[ ! -f #{oscm_keypair_crowbar_sshkey}] && yes y | ssh-keygen -t rsa -f #{oscm_keypair_crowbar_sshkey} -N ''"
      command_out = shell_out(command)
    end
    action :create
end

execute "create_oscm_instance_stack" do
  command lazy { "#{openstack_cmd} #{openstack_args_heat} stack create --parameter app_volume_id=#{node[:oscm][:openstack][:volume_stack][:app_volume_id]} \
  --parameter db_volume_id=#{node[:oscm][:openstack][:volume_stack][:db_volume_id]} \
  --parameter image=#{oscm_image} --parameter flavor=#{oscm_flavor_name} \
  --parameter mail_port=#{oscm_mail_port} --parameter registry_port=#{oscm_docker_port} \
  --parameter-file ssh_cert=#{oscm_keypair_crowbar_sshkey}.pub \
  -t #{oscm_install_path}/application.yaml --wait #{oscm_instancestack_name}" }
  not_if "#{openstack_cmd} #{openstack_args_heat} stack list -c 'Stack Name' -f value | egrep -q '^#{oscm_instancestack_name}$'"
end

ruby_block "get_oscm_floating_ip" do
    block do
      Chef::Resource::RubyBlock.send(:include, Chef::Mixin::ShellOut)
      command = "#{openstack_cmd} #{openstack_args_heat} stack output show -f shell --variable output_value #{oscm_instancestack_name} ip_appserver | grep -Po '(?<=^output_value=\")[^\"]*'"
      command_out = shell_out(command)
      node[:oscm][:openstack][:instance_stack][:ip_appserver] = command_out.stdout.strip
    end
    action :create
end

if node[:oscm][:api][:protocol] == "https"
  ssl_setup "setting up ssl for oscm" do
    generate_certs node[:oscm][:ssl][:generate_certs]
    certfile node[:oscm][:ssl][:certfile]
    keyfile node[:oscm][:ssl][:keyfile]
    group oscm_group
    fqdn node[:oscm][:ssl][:fqdn].empty? ? node[:oscm][:openstack][:instance_stack][:ip_appserver] : node[:oscm][:ssl][:fqdn]
    ca_certs node[:oscm][:ssl][:ca_certs]
  end
end

ruby_block "get_oscm_secrets" do
    block do
      Chef::Resource::RubyBlock.send(:include, Chef::Mixin::ShellOut)
      command = "#{openstack_cmd} #{openstack_args_heat} stack output show -f shell --variable output_value #{oscm_instancestack_name} db_password | grep -Po '(?<=^output_value=\")[^\"]*'"
      command_out = shell_out(command)
      node[:oscm][:openstack][:instance_stack][:db_password] = command_out.stdout.strip
      command = "#{openstack_cmd} #{openstack_args_heat} stack output show -f shell --variable output_value #{oscm_instancestack_name} db_core_password | grep -Po '(?<=^output_value=\")[^\"]*'"
      command_out = shell_out(command)
      node[:oscm][:openstack][:instance_stack][:db_core_password] = command_out.stdout.strip
      command = "#{openstack_cmd} #{openstack_args_heat} stack output show -f shell --variable output_value #{oscm_instancestack_name} db_app_password | grep -Po '(?<=^output_value=\")[^\"]*'"
      command_out = shell_out(command)
      node[:oscm][:openstack][:instance_stack][:db_app_password] = command_out.stdout.strip
      command = "#{openstack_cmd} #{openstack_args_heat} stack output show -f shell --variable output_value #{oscm_instancestack_name} key_secret | grep -Po '(?<=^output_value=\")[^\"]*'"
      command_out = shell_out(command)
      node[:oscm][:openstack][:instance_stack][:key_secret] = command_out.stdout.strip
    end
    action :create
end

template "#{oscm_install_path}/user-data/oscm-config" do
  source "oscm.conf.erb"
  owner oscm_group
  group oscm_group
  mode 0640
  variables(
    mail: node[:oscm][:mail],
    docker: node[:oscm][:docker],
    proxy: node[:oscm][:proxy],
    host_fqdn: node[:oscm][:ssl][:fqdn].empty? ? node[:oscm][:openstack][:instance_stack][:ip_appserver] : node[:oscm][:ssl][:fqdn],
    instance: node[:oscm][:openstack][:instance_stack]
  )
end

template "#{oscm_install_path}/docker-compose-initdb.yml" do
  source "docker-compose-initdb.yml.erb"
  owner oscm_group
  group oscm_group
  mode 0640
  variables(
    docker: node[:oscm][:docker]
  )
end

template "#{oscm_install_path}/docker-compose-oscm.yml" do
  source "docker-compose-oscm.yml.erb"
  owner oscm_group
  group oscm_group
  mode 0640
  variables(
    docker: node[:oscm][:docker]
  )
end

template "#{oscm_install_path}/var.env" do
  source "var.env.erb"
  owner oscm_group
  group oscm_group
  mode 0640
  variables(
    mail: node[:oscm][:mail],
    docker: node[:oscm][:docker],
    proxy: node[:oscm][:proxy],
    host_fqdn: node[:oscm][:ssl][:fqdn].empty? ? node[:oscm][:openstack][:instance_stack][:ip_appserver] : node[:oscm][:ssl][:fqdn],
    instance: node[:oscm][:openstack][:instance_stack]
  )
end

ruby_block "inject_oscm_scripts" do
    block do
      args = "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i #{oscm_keypair_crowbar_sshkey}"
      ip_appserver = node[:oscm][:openstack][:instance_stack][:ip_appserver]
      Chef::Resource::RubyBlock.send(:include, Chef::Mixin::ShellOut)
      command = "ssh #{args} #{ip_appserver} 'mkdir -p #{oscm_config_path}/docker-compose'"
      command_out = shell_out(command)
      command = "scp #{args} #{oscm_install_path}/user-data/oscm-config #{ip_appserver}:#{oscm_config_path}"
      command_out = shell_out(command)
      command = "scp #{args} #{oscm_install_path}/docker-compose-*.yml #{ip_appserver}:#{oscm_config_path}/docker-compose"
      command_out = shell_out(command)
      if node[:oscm][:api][:protocol] == "https"
        command = "ssh #{args} #{ip_appserver} 'mkdir -p #{oscm_config_path}/ssl'"
        command_out = shell_out(command)
        command = "scp #{args} #{oscm_ssl_certfile} #{ip_appserver}:#{oscm_config_path}/ssl/oscm.crt"
        command_out = shell_out(command)
        command = "scp #{args} #{oscm_ssl_keyfile} #{ip_appserver}:#{oscm_config_path}/ssl/oscm.key"
        command_out = shell_out(command)
        command = "scp #{args} #{oscm_ssl_cacerts} #{ip_appserver}:#{oscm_config_path}/ssl/oscm.chain"
      end
      command = "scp #{args} #{oscm_install_path}/user-data/deploy-oscmserver #{ip_appserver}:#{oscm_config_path}"
      command_out = shell_out(command)
      command = "ssh #{args} #{ip_appserver} 'chmod 755 #{oscm_config_path}/deploy-oscmserver'"
      command_out = shell_out(command)
      command = "ssh #{args} #{ip_appserver} '#{oscm_config_path}/deploy-oscmserver'"
      command_out = shell_out(command)
    end
    action :create
end

