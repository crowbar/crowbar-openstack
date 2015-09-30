# Copyright 2013 SUSE, Inc.
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

ha_enabled = node[:heat][:ha][:enabled]

db_settings = fetch_database_settings

include_recipe "database::client"
include_recipe "#{db_settings[:backend_name]}::client"
include_recipe "#{db_settings[:backend_name]}::python-client"

crowbar_pacemaker_sync_mark "wait-heat_database"

# Create the Heat Database
database "create #{node[:heat][:db][:database]} database" do
  connection db_settings[:connection]
  database_name node[:heat][:db][:database]
  provider db_settings[:provider]
  action :create
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

database_user "create heat database user" do
  host "%"
  connection db_settings[:connection]
  username node[:heat][:db][:user]
  password node[:heat][:db][:password]
  provider db_settings[:user_provider]
  action :create
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

database_user "grant database access for heat database user" do
  connection db_settings[:connection]
  username node[:heat][:db][:user]
  password node[:heat][:db][:password]
  database_name node[:heat][:db][:database]
  host "%"
  privileges db_settings[:privs]
  provider db_settings[:user_provider]
  action :grant
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

crowbar_pacemaker_sync_mark "create-heat_database"

node[:heat][:platform][:packages].each do |p|
  package p
end

directory "/var/cache/heat" do
  owner node[:heat][:user]
  group node[:heat][:group]
  mode 00750
  action :create
end

directory "/etc/heat/environment.d" do
  owner "root"
  group "root"
  mode 00755
  action :create
end

keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)

if ha_enabled
  admin_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "admin").address
  bind_host = admin_address
  api_port = node[:heat][:ha][:ports][:api_port]
  cfn_port = node[:heat][:ha][:ports][:cfn_port]
  cloud_watch_port = node[:heat][:ha][:ports][:cloud_watch_port]
else
  bind_host = "0.0.0.0"
  api_port = node[:heat][:api][:port]
  cfn_port = node[:heat][:api][:cfn_port]
  cloud_watch_port = node[:heat][:api][:cloud_watch_port]
end

my_admin_host = CrowbarHelper.get_host_for_admin_url(node, ha_enabled)
my_public_host = CrowbarHelper.get_host_for_public_url(node, node[:heat][:api][:protocol] == "https", ha_enabled)

db_connection = "#{db_settings[:url_scheme]}://#{node[:heat][:db][:user]}:#{node[:heat][:db][:password]}@#{db_settings[:address]}/#{node[:heat][:db][:database]}"

crowbar_pacemaker_sync_mark "wait-heat_register"

keystone_register "heat wakeup keystone" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  token keystone_settings["admin_token"]
  action :wakeup
end

keystone_register "register heat user" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  token keystone_settings["admin_token"]
  user_name keystone_settings["service_user"]
  user_password keystone_settings["service_password"]
  tenant_name keystone_settings["service_tenant"]
  action :add_user
end

keystone_register "give heat user access" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  token keystone_settings["admin_token"]
  user_name keystone_settings["service_user"]
  tenant_name keystone_settings["service_tenant"]
  role_name "admin"
  action :add_access
end

keystone_register "add heat stack user role" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  token keystone_settings["admin_token"]
  user_name keystone_settings["service_user"]
  tenant_name keystone_settings["service_tenant"]
  role_name "heat_stack_user"
  action :add_role
end

keystone_register "add heat stack owner role" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  token keystone_settings["admin_token"]
  user_name keystone_settings["service_user"]
  tenant_name keystone_settings["service_tenant"]
  role_name "heat_stack_owner"
  action :add_role
end

keystone_register "give admin access to stack owner role" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  token keystone_settings["admin_token"]
  user_name keystone_settings["admin_user"]
  tenant_name keystone_settings["default_tenant"]
  role_name "heat_stack_owner"
  action :add_access
end

package "python-openstackclient" do
  action :install
end

stack_user_domain_name = "heat"
insecure = keystone_settings["insecure"] ? "--insecure" : ""

bash "register heat domain" do
  user "root"
  code <<-EOF

    # Find domain ID
    id=
    eval $(openstack #{insecure} \
        domain show \
        -f shell --variable id \
        #{stack_user_domain_name})

    HEAT_DOMAIN_ID=$id

    if [ -z "$HEAT_DOMAIN_ID" ]; then
        id=
        eval $(openstack #{insecure} \
            domain create \
            -f shell --variable id \
            --description "Owns users and projects created by heat" \
            #{stack_user_domain_name})
        HEAT_DOMAIN_ID=$id
    fi

    [ -n "$HEAT_DOMAIN_ID" ] || exit 1

    # Find user ID
    STACK_DOMAIN_ADMIN_ID=

    # we need to loop, as there might be users with this name in different
    # domains; unfortunately --domain doesn't allow fetching users from just
    # one domain
    for userid in $(openstack #{insecure} \
                        user list \
                        -f csv \
                        --domain $HEAT_DOMAIN_ID \
                        | grep \"#{node[:heat]["stack_domain_admin"]}\" | cut -d , -f 1 | sed 's/"//g'); do
        domain_id=
        eval $(openstack #{insecure} \
            user show \
            -f shell --variable domain_id \
            $userid)

        if [ x"$domain_id" = x"$HEAT_DOMAIN_ID" ]; then
            STACK_DOMAIN_ADMIN_ID=$userid
            openstack #{insecure} \
                user set \
                --domain $HEAT_DOMAIN_ID \
                --password #{node[:heat]["stack_domain_admin_password"]} \
                --description "Manages users and projects created by heat" \
                $STACK_DOMAIN_ADMIN_ID
            break
        fi
    done

    if [ -z "$STACK_DOMAIN_ADMIN_ID" ]; then
        id=
        eval $(openstack #{insecure} \
            user create \
            -f shell --variable id \
            --domain $HEAT_DOMAIN_ID \
            --password #{node[:heat]["stack_domain_admin_password"]} \
            --description "Manages users and projects created by heat" \
            #{node[:heat]["stack_domain_admin"]})
        STACK_DOMAIN_ADMIN_ID=$id
    fi

    [ -n "$STACK_DOMAIN_ADMIN_ID" ] || exit 1

    # Make user an admin
    if ! openstack #{insecure} \
            role list \
            -f csv --column Name \
            --domain $HEAT_DOMAIN_ID \
            --user $STACK_DOMAIN_ADMIN_ID \
            | grep -q \"admin\"; then
        openstack #{insecure} \
            role add \
            --domain $HEAT_DOMAIN_ID \
            --user $STACK_DOMAIN_ADMIN_ID \
            admin
    fi
  EOF
  environment ({
    "OS_USERNAME" => keystone_settings["admin_user"],
    "OS_PASSWORD" => keystone_settings["admin_password"],
    "OS_TENANT_NAME" => keystone_settings["admin_tenant"],
    "OS_AUTH_URL" => "#{keystone_settings['protocol']}://#{keystone_settings['internal_url_host']}:#{keystone_settings['service_port']}/v3",
    "OS_REGION_NAME" => keystone_settings["endpoint_region"],
    "OS_IDENTITY_API_VERSION" => "3"
  })
end

# Create Heat CloudFormation service
keystone_register "register Heat CloudFormation Service" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  token keystone_settings["admin_token"]
  service_name "heat-cfn"
  service_type "cloudformation"
  service_description "Heat CloudFormation Service"
  action :add_service
end

keystone_register "register heat Cfn endpoint" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  token keystone_settings["admin_token"]
  endpoint_service "heat-cfn"
  endpoint_region keystone_settings["endpoint_region"]
  endpoint_publicURL "#{node[:heat][:api][:protocol]}://#{my_public_host}:#{node[:heat][:api][:cfn_port]}/v1"
  endpoint_adminURL "#{node[:heat][:api][:protocol]}://#{my_admin_host}:#{node[:heat][:api][:cfn_port]}/v1"
  endpoint_internalURL "#{node[:heat][:api][:protocol]}://#{my_admin_host}:#{node[:heat][:api][:cfn_port]}/v1"
  #  endpoint_global true
  #  endpoint_enabled true
  action :add_endpoint_template
end

# Create Heat service
keystone_register "register Heat Service" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  token keystone_settings["admin_token"]
  service_name "heat"
  service_type "orchestration"
  service_description "Heat Service"
  action :add_service
end

keystone_register "register heat endpoint" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  token keystone_settings["admin_token"]
  endpoint_service "heat"
  endpoint_region keystone_settings["endpoint_region"]
  endpoint_publicURL "#{node[:heat][:api][:protocol]}://#{my_public_host}:#{node[:heat][:api][:port]}/v1/$(tenant_id)s"
  endpoint_adminURL "#{node[:heat][:api][:protocol]}://#{my_admin_host}:#{node[:heat][:api][:port]}/v1/$(tenant_id)s"
  endpoint_internalURL "#{node[:heat][:api][:protocol]}://#{my_admin_host}:#{node[:heat][:api][:port]}/v1/$(tenant_id)s"
  #  endpoint_global true
  #  endpoint_enabled true
  action :add_endpoint_template
end

crowbar_pacemaker_sync_mark "create-heat_register"

shell_get_stack_user_domain = <<-EOF
  export OS_URL="#{keystone_settings['protocol']}://#{keystone_settings['internal_url_host']}:#{keystone_settings['service_port']}/v3"
  eval $(openstack --os-token #{keystone_settings['admin_token']} \
    --os-url=$OS_URL \
    --os-region-name='#{keystone_settings['endpoint_region']}' \
    --os-identity-api-version=3 #{insecure} domain show -f shell --variable id #{stack_user_domain_name});
  echo $id
EOF

template "/etc/heat/heat.conf" do
  source "heat.conf.erb"
  owner "root"
  group node[:heat][:group]
  mode "0640"
  variables(
    debug: node[:heat][:debug],
    verbose: node[:heat][:verbose],
    rabbit_settings: fetch_rabbitmq_settings,
    keystone_settings: keystone_settings,
    database_connection: db_connection,
    bind_host: bind_host,
    api_port: api_port,
    cloud_watch_port: cloud_watch_port,
    instance_user: node[:heat][:default_instance_user],
    cfn_port: cfn_port,
    auth_encryption_key: node[:heat][:auth_encryption_key],
    heat_metadata_server_url: "#{node[:heat][:api][:protocol]}://#{my_public_host}:#{node[:heat][:api][:cfn_port]}",
    heat_waitcondition_server_url: "#{node[:heat][:api][:protocol]}://#{my_public_host}:#{node[:heat][:api][:cfn_port]}/v1/waitcondition",
    heat_watch_server_url: "#{node[:heat][:api][:protocol]}://#{my_public_host}:#{node[:heat][:api][:cloud_watch_port]}",
    stack_user_domain: %x[ #{shell_get_stack_user_domain} ].chomp,
    stack_domain_admin: node[:heat]["stack_domain_admin"],
    stack_domain_admin_password: node[:heat]["stack_domain_admin_password"]
  )
end

service "heat-engine" do
  service_name node[:heat][:engine][:service_name]
  supports status: true, restart: true
  action [:enable, :start]
  subscribes :restart, resources("template[/etc/heat/heat.conf]")
  provider Chef::Provider::CrowbarPacemakerService if ha_enabled
end

template "/etc/heat/loadbalancer.template" do
  source "loadbalancer.template.erb"
  owner "root"
  group node[:heat][:group]
  mode "0640"
  notifies :restart, "service[heat-engine]", :delayed
  only_if { node[:platform_family] == "suse" }
end

service "heat-api" do
  service_name node[:heat][:api][:service_name]
  supports status: true, restart: true
  action [:enable, :start]
  subscribes :restart, resources("template[/etc/heat/heat.conf]")
  provider Chef::Provider::CrowbarPacemakerService if ha_enabled
end

service "heat-api-cfn" do
  service_name node[:heat][:api_cfn][:service_name]
  supports status: true, restart: true
  action [:enable, :start]
  subscribes :restart, resources("template[/etc/heat/heat.conf]")
  provider Chef::Provider::CrowbarPacemakerService if ha_enabled
end

service "heat-api-cloudwatch" do
  service_name node[:heat][:api_cloudwatch][:service_name]
  supports status: true, restart: true
  action [:enable, :start]
  subscribes :restart, resources("template[/etc/heat/heat.conf]")
  provider Chef::Provider::CrowbarPacemakerService if ha_enabled
end

crowbar_pacemaker_sync_mark "wait-heat_db_sync"

execute "heat-manage db_sync" do
  user node[:heat][:user]
  group node[:heat][:group]
  command "heat-manage db_sync"
  # We only do the sync the first time, and only if we're not doing HA or if we
  # are the founder of the HA cluster (so that it's really only done once).
  only_if { !node[:heat][:db_synced] && (!ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node)) }
end

# We want to keep a note that we've done db_sync, so we don't do it again.
# If we were doing that outside a ruby_block, we would add the note in the
# compile phase, before the actual db_sync is done (which is wrong, since it
# could possibly not be reached in case of errors).
ruby_block "mark node for heat db_sync" do
  block do
    node[:heat][:db_synced] = true
    node.save
  end
  action :nothing
  subscribes :create, "execute[heat-manage db_sync]", :immediately
end

crowbar_pacemaker_sync_mark "create-heat_db_sync"

if ha_enabled
  log "HA support for heat is enabled"
  include_recipe "heat::ha"
else
  log "HA support for heat is disabled"
end

node.save
