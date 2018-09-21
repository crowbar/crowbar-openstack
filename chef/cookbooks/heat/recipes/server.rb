# Copyright 2016 SUSE, Inc.
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
use_crowbar_pacemaker_service = ha_enabled && node[:pacemaker][:clone_stateless_services]

db_settings = fetch_database_settings

include_recipe "database::client"
include_recipe "#{db_settings[:backend_name]}::client"
include_recipe "#{db_settings[:backend_name]}::python-client"

crowbar_pacemaker_sync_mark "wait-heat_database" if ha_enabled

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
  require_ssl db_settings[:connection][:ssl][:enabled]
  action :grant
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

crowbar_pacemaker_sync_mark "create-heat_database" if ha_enabled

node[:heat][:platform][:packages].each do |p|
  package p
end

node[:heat][:platform][:plugin_packages].each do |p|
  package p
end

# install Cisco GBP plugin if needed
neutron_server = search(:node, "roles:neutron-server").first || []
unless neutron_server.empty?
  if neutron_server[:neutron][:ml2_mechanism_drivers].include?("apic_gbp")
    # Install GBP plugin if Cisco APIC driver is set to apic_gbp
    node[:heat][:platform][:gbp_plugin_packages].each do |p|
      package p
    end
  end
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

if node[:heat][:api][:protocol] == "https"
  ssl_setup "setting up ssl for heat" do
    generate_certs node[:heat][:ssl][:generate_certs]
    certfile node[:heat][:ssl][:certfile]
    keyfile node[:heat][:ssl][:keyfile]
    group node[:heat][:group]
    fqdn node[:fqdn]
    cert_required node[:heat][:ssl][:cert_required]
    ca_certs node[:heat][:ssl][:ca_certs]
  end
end

memcached_servers = MemcachedHelper.get_memcached_servers(
  ha_enabled ? CrowbarPacemakerHelper.cluster_nodes(node, "heat-server") : [node]
)
memcached_instance("heat-server")

keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)

bind_host, api_port, cfn_port = HeatHelper.get_bind_host_port(node)

my_admin_host = CrowbarHelper.get_host_for_admin_url(node, ha_enabled)
my_public_host = CrowbarHelper.get_host_for_public_url(node, node[:heat][:api][:protocol] == "https", ha_enabled)

db_connection = fetch_database_connection_string(node[:heat][:db])

crowbar_pacemaker_sync_mark "wait-heat_register" if ha_enabled

register_auth_hash = { user: keystone_settings["admin_user"],
                       password: keystone_settings["admin_password"],
                       project: keystone_settings["admin_project"] }

keystone_register "heat wakeup keystone" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  action :wakeup
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

keystone_register "register heat user" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  user_name keystone_settings["service_user"]
  user_password keystone_settings["service_password"]
  project_name keystone_settings["service_tenant"]
  action :add_user
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

keystone_register "give heat user access" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  user_name keystone_settings["service_user"]
  project_name keystone_settings["service_tenant"]
  role_name "admin"
  action :add_access
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

keystone_register "add heat stack user role" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  role_name "heat_stack_user"
  action :add_role
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

node[:heat][:trusts_delegated_roles].each do |role|
  keystone_register "Create stack owner role #{role}" do
    protocol keystone_settings["protocol"]
    insecure keystone_settings["insecure"]
    host keystone_settings["internal_url_host"]
    port keystone_settings["admin_port"]
    auth register_auth_hash
    role_name role
    action :add_role
    only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end

  keystone_register "give admin access to stack owner role #{role}" do
    protocol keystone_settings["protocol"]
    insecure keystone_settings["insecure"]
    host keystone_settings["internal_url_host"]
    port keystone_settings["admin_port"]
    auth register_auth_hash
    user_name keystone_settings["admin_user"]
    project_name keystone_settings["default_tenant"]
    role_name role
    action :add_access
    only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end
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
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

# Create Heat CloudFormation service
keystone_register "register Heat CloudFormation Service" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  service_name "heat-cfn"
  service_type "cloudformation"
  service_description "Heat CloudFormation Service"
  action :add_service
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

keystone_register "register heat Cfn endpoint" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  endpoint_service "heat-cfn"
  endpoint_region keystone_settings["endpoint_region"]
  endpoint_publicURL "#{node[:heat][:api][:protocol]}://#{my_public_host}:#{node[:heat][:api][:cfn_port]}/v1"
  endpoint_adminURL "#{node[:heat][:api][:protocol]}://#{my_admin_host}:#{node[:heat][:api][:cfn_port]}/v1"
  endpoint_internalURL "#{node[:heat][:api][:protocol]}://#{my_admin_host}:#{node[:heat][:api][:cfn_port]}/v1"
  action :add_endpoint
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

# Create Heat service
keystone_register "register Heat Service" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  service_name "heat"
  service_type "orchestration"
  service_description "Heat Service"
  action :add_service
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

keystone_register "register heat endpoint" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  endpoint_service "heat"
  endpoint_region keystone_settings["endpoint_region"]
  endpoint_publicURL "#{node[:heat][:api][:protocol]}://"\
                     "#{my_public_host}:"\
                     "#{node[:heat][:api][:port]}/v1/$(project_id)s"
  endpoint_adminURL "#{node[:heat][:api][:protocol]}://"\
                    "#{my_admin_host}:"\
                    "#{node[:heat][:api][:port]}/v1/$(project_id)s"
  endpoint_internalURL "#{node[:heat][:api][:protocol]}://"\
                       "#{my_admin_host}:"\
                       "#{node[:heat][:api][:port]}/v1/$(project_id)s"
  action :add_endpoint
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

crowbar_pacemaker_sync_mark "create-heat_register" if ha_enabled

ruby_block "get stack user domain" do
  block do
    url = "#{keystone_settings["protocol"]}://#{keystone_settings["internal_url_host"]}"
    url << ":#{keystone_settings["service_port"]}/v3"
    env = "OS_USERNAME='#{keystone_settings["admin_user"]}' "
    env << "OS_PASSWORD='#{keystone_settings["admin_password"]}' "
    env << "OS_PROJECT_NAME='#{keystone_settings["admin_tenant"]}' "
    env << "OS_AUTH_URL='#{url}' "
    env << "OS_REGION_NAME='#{keystone_settings["endpoint_region"]}' "
    env << "OS_IDENTITY_API_VERSION=3"
    stack_user_domain_id = `#{env} openstack #{insecure} \
domain show -f value -c id #{stack_user_domain_name}`
    raise "Could not obtain the stack user domain id" if stack_user_domain_id.empty?
    node[:heat][:stack_user_domain_id] = stack_user_domain_id.strip
  end
end

template "/etc/heat/heat.conf.d/100-heat.conf" do
  source "heat.conf.erb"
  owner "root"
  group node[:heat][:group]
  mode "0640"
  variables(
    lazy {
      {
        debug: node[:heat][:debug],
        rabbit_settings: fetch_rabbitmq_settings,
        keystone_settings: keystone_settings,
        memcached_servers: memcached_servers,
        database_connection: db_connection,
        bind_host: bind_host,
        api_port: api_port,
        cfn_port: cfn_port,
        auth_encryption_key: node[:heat][:auth_encryption_key][0, 32],
        heat_metadata_server_url: "#{node[:heat][:api][:protocol]}://#{my_public_host}:#{node[:heat][:api][:cfn_port]}",
        heat_waitcondition_server_url: "#{node[:heat][:api][:protocol]}://#{my_public_host}:#{node[:heat][:api][:cfn_port]}/v1/waitcondition",
        stack_user_domain: node[:heat][:stack_user_domain_id],
        stack_domain_admin: node[:heat]["stack_domain_admin"],
        stack_domain_admin_password: node[:heat]["stack_domain_admin_password"],
        trusts_delegated_roles: node[:heat][:trusts_delegated_roles],
        insecure: keystone_settings["insecure"],
        heat_ssl: node[:heat][:ssl]
      }
    }
  )
end

crowbar_pacemaker_sync_mark "wait-heat_db_sync" if ha_enabled

execute "heat-manage db_sync" do
  user node[:heat][:user]
  group node[:heat][:group]
  command "heat-manage db_sync"
  # We only do the sync the first time, and only if we're not doing HA or if we
  # are the founder of the HA cluster (so that it's really only done once).
  only_if {
    !node[:heat][:db_synced] && (!ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node))
  }
end

# We want to keep a note that we've done db_sync, so we don't do it again.
# If we were doing that outside a ruby_block, we would add the note in the
# compile phase, before the actual db_sync is done (which is wrong, since it
# could possibly not be reached in case of errors).
ruby_block "mark node for heat db_sync" do
  block do
    node.set[:heat][:db_synced] = true
    node.save
  end
  action :nothing
  subscribes :create, "execute[heat-manage db_sync]", :immediately
end

crowbar_pacemaker_sync_mark "create-heat_db_sync" if ha_enabled

service "heat-engine" do
  service_name node[:heat][:engine][:service_name]
  supports status: true, restart: true
  action [:enable, :start]
  subscribes :restart, resources("template[/etc/heat/heat.conf.d/100-heat.conf]")
  provider Chef::Provider::CrowbarPacemakerService if use_crowbar_pacemaker_service
end
utils_systemd_service_restart "heat-engine" do
  action use_crowbar_pacemaker_service ? :disable : :enable
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
  subscribes :restart, resources("template[/etc/heat/heat.conf.d/100-heat.conf]")
  provider Chef::Provider::CrowbarPacemakerService if use_crowbar_pacemaker_service
end
utils_systemd_service_restart "heat-api" do
  action use_crowbar_pacemaker_service ? :disable : :enable
end

service "heat-api-cfn" do
  service_name node[:heat][:api_cfn][:service_name]
  supports status: true, restart: true
  action [:enable, :start]
  subscribes :restart, resources("template[/etc/heat/heat.conf.d/100-heat.conf]")
  provider Chef::Provider::CrowbarPacemakerService if use_crowbar_pacemaker_service
end
utils_systemd_service_restart "heat-api-cfn" do
  action use_crowbar_pacemaker_service ? :disable : :enable
end

if ha_enabled
  log "HA support for heat is enabled"
  include_recipe "heat::ha"
else
  log "HA support for heat is disabled"
end
