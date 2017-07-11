#
# Cookbook Name:: glance
# Recipe:: api
#
#

include_recipe "#{@cookbook_name}::common"

package "glance-api" do
  package_name "openstack-glance-api" if ["rhel", "suse"].include?(node[:platform_family])
end

# Install qemu-img (dependency present in suse packages)
case node[:platform_family]
when "debian"
  package "qemu-utils"
when "rhel", "fedora"
  package "qemu-img"
end

keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)

if node[:glance][:api][:protocol] == "https"
  ssl_setup "setting up ssl for glance" do
    generate_certs node[:glance][:ssl][:generate_certs]
    certfile node[:glance][:ssl][:certfile]
    keyfile node[:glance][:ssl][:keyfile]
    group node[:glance][:group]
    fqdn node[:fqdn]
    cert_required node[:glance][:ssl][:cert_required]
    ca_certs node[:glance][:ssl][:ca_certs]
  end
end

# TODO: there's no dependency in terms of proposal on swift
swift_api_insecure = false
swifts = search(:node, "roles:swift-proxy") || []
if swifts.length > 0
  swift = swifts[0]
  swift_api_insecure = swift[:swift][:ssl][:enabled] && swift[:swift][:ssl][:insecure]
end

#TODO: glance should depend on cinder, but cinder already depends on glance :/
# so we have to do something like this
cinder_api_insecure = false
cinders = search(:node, "roles:cinder-controller") || []
if cinders.length > 0
  cinder = cinders[0]
  cinder_api_insecure = cinder[:cinder][:api][:protocol] == "https" && cinder[:cinder][:ssl][:insecure]
end

ironics = node_search_with_cache("roles:ironic-server") || []

network_settings = GlanceHelper.network_settings(node)

glance_stores = node.default[:glance][:glance_stores].dup
glance_stores += ["vmware"] unless node[:glance][:vsphere][:host].empty?

# glance_stores unconditionally enables cinder and swift stores, so we need
# to install the necessary clients
package "python-cinderclient"
package "python-swiftclient"

directory node[:glance][:filesystem_store_datadir] do
  owner node[:glance][:user]
  group node[:glance][:group]
  mode 0755
  action :create
end

template node[:glance][:api][:config_file] do
  source "glance-api.conf.erb"
  owner "root"
  group node[:glance][:group]
  mode 0640
  variables(
      bind_host: network_settings[:api][:bind_host],
      bind_port: network_settings[:api][:bind_port],
      registry_bind_host: network_settings[:registry][:bind_host],
      registry_bind_port: network_settings[:registry][:bind_port],
      keystone_settings: keystone_settings,
      rabbit_settings: fetch_rabbitmq_settings,
      swift_api_insecure: swift_api_insecure,
      cinder_api_insecure: cinder_api_insecure,
      # v1 api is (temporarily) enforced by ironic
      # Newton version of Ironic supports only v1
      # Ocata and Pike have option to set glance_api_version
      # Queens will only support v2
      enable_v1: !ironics.empty? || node[:glance][:enable_v1],
      glance_stores: glance_stores.join(",")
  )
  notifies :restart, "service[#{node[:glance][:api][:service_name]}]"
end

template "/etc/glance/glance-swift.conf" do
  source "glance-swift.conf.erb"
  owner "root"
  group node[:glance][:group]
  mode 0640
  variables(
    keystone_settings: keystone_settings
  )
  notifies :restart, "service[#{node[:glance][:api][:service_name]}]"
end

# If `show_multiple_locations` is enabled we need to update
# policy.json in a more restrictive way.  Only admin (or image owner)
# can now update the `image_location` metadate field.
#
# For more information check bsc#1023507, and upstream bug:
# https://bugs.launchpad.net/ossn/+bug/1549483
#
# NOTE(aplanas) -- policy.json needs to be synchronized to current
# version of OpenStack.
template "/etc/glance/policy.json" do
  source "policy.json.erb"
  owner "root"
  group "root"
  mode 0o644
  variables(
    show_multiple_locations: node[:glance][:show_storage_location]
  )
  notifies :restart, "service[#{node[:glance][:api][:service_name]}]"
end

# ensure swift tempurl key only if some agent_* drivers are enabled in ironic
if swifts.any? && node[:glance][:default_store] == "swift" && \
    ironics.any? && ironics.first[:ironic][:enabled_drivers].any? { |d| d.start_with?("agent_") }
  swift_command = "swift --os-username #{keystone_settings["service_user"]}"
  swift_command << " --os-password #{keystone_settings["service_password"]}"
  swift_command << " --os-tenant-name #{keystone_settings["service_tenant"]}"
  swift_command << " --os-auth-url #{keystone_settings["public_auth_url"]}"
  swift_command << " --os-identity-api-version 3"
  swift_command << (swift_api_insecure ? " --insecure" : "")

  get_tempurl_key = "#{swift_command} stat | grep -m1 'Meta Temp-Url-Key:' | awk '{print $3}'"
  tempurl_key = Mixlib::ShellOut.new(get_tempurl_key).run_command.stdout.chomp
  # no tempurl key set, set a random one
  if tempurl_key.empty?
    tempurl_key = secure_password
    execute "set-glance-tempurl-key" do
      command "#{swift_command} post -m 'Temp-Url-Key:#{tempurl_key}'"
      user node[:glance][:user]
      group node[:glance][:group]
    end
  end
end

ha_enabled = node[:glance][:ha][:enabled]
my_admin_host = CrowbarHelper.get_host_for_admin_url(node, ha_enabled)
my_public_host = CrowbarHelper.get_host_for_public_url(node, node[:glance][:api][:protocol] == "https", ha_enabled)

# If we let the service bind to all IPs, then the service is obviously usable
# from the public network. Otherwise, the endpoint URL should use the unique
# IP that will be listened on.
if node[:glance][:api][:bind_open_address]
  endpoint_admin_ip = my_admin_host
  endpoint_public_ip = my_public_host
else
  endpoint_admin_ip = my_admin_host
  endpoint_public_ip = my_admin_host
end
api_port = node["glance"]["api"]["bind_port"]
glance_protocol = node[:glance][:api][:protocol]

crowbar_pacemaker_sync_mark "wait-glance_register_service" if ha_enabled

register_auth_hash = { user: keystone_settings["admin_user"],
                       password: keystone_settings["admin_password"],
                       tenant: keystone_settings["admin_tenant"] }

keystone_register "register glance service" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  service_name "glance"
  service_type "image"
  service_description "Openstack Glance Service"
  action :add_service
end

keystone_register "register glance endpoint" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  endpoint_service "glance"
  endpoint_region keystone_settings["endpoint_region"]
  endpoint_publicURL "#{glance_protocol}://#{endpoint_public_ip}:#{api_port}"
  endpoint_adminURL "#{glance_protocol}://#{endpoint_admin_ip}:#{api_port}"
  endpoint_internalURL "#{glance_protocol}://#{endpoint_admin_ip}:#{api_port}"
#  endpoint_global true
#  endpoint_enabled true
  action :add_endpoint_template
end

crowbar_pacemaker_sync_mark "create-glance_register_service" if ha_enabled

glance_service "api"
