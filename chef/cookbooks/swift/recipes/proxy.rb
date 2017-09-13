#
# Copyright 2011, Dell
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
# Author: andi abes
#

include_recipe "utils"
include_recipe "swift::auth"
# Note: we always want to setup rsync, even if we do not do anything else; this
# will allow the ring-compute node to push the rings.
include_recipe "swift::rsync"

dirty = false

if node.roles.include?("swift-storage") && node[:swift][:devs].nil?
  # If we're a storage node and have no device yet, then it simply means that we
  # haven't looked for devices yet, which also means that we won't have rings at
  # this point in time, so swift-proxy will fail.
  Chef::Log.info("Not setting up swift-proxy daemon; this chef run is only used to find disks on storage nodes.")
  return
end

if node.roles.include?("swift-ring-compute") && !::File.exist?("/etc/swift/object.ring.gz")
  # Similarly to above; the difference is that we will have the rings in the
  # execute phase, but we do not want to be the only proxy node with the rings
  # (which would be the case, since we're in the ring-compute pass of swift
  # orchestration): we want all nodes to start swift-proxy at the same time.
  Chef::Log.info("Not setting up swift-proxy daemon; this chef run is only used to compute the rings.")
  return
end

if node.roles.include?("swift-storage") && !node["swift"]["storage_init_done"]
  # We're a storage node, and we have devices. But have we setup the storage
  # daemons? If not, then we're not in the chef run for swift-proxy yet.
  Chef::Log.info("Not setting up swift-proxy daemon; this chef run is only used to setup swift-{account,container,object}.")
  return
end

local_ip = Swift::Evaluator.get_ip_by_type(node, :admin_ip_expr)
public_ip = Swift::Evaluator.get_ip_by_type(node, :public_ip_expr)

ha_enabled = node[:swift][:ha][:enabled]

bind_host, bind_port = SwiftHelper.get_bind_host_port(node)

admin_host = CrowbarHelper.get_host_for_admin_url(node, ha_enabled)
public_host = CrowbarHelper.get_host_for_public_url(node, node[:swift][:ssl][:enabled], ha_enabled)
swift_protocol = node[:swift][:ssl][:enabled] ? "https" : "http"

###
# bucket to collect all the config items that end up in the proxy config template
proxy_config = {}
proxy_config[:bind_host] = bind_host
proxy_config[:bind_port] = bind_port
proxy_config[:auth_method] = node[:swift][:auth_method]
proxy_config[:user] = node[:swift][:user]
proxy_config[:debug] = node[:swift][:debug]
proxy_config[:admin_host] = admin_host
proxy_config[:proxy_port] = node[:swift][:ports][:proxy]
### middleware items
proxy_config[:clock_accuracy] = node[:swift][:middlewares][:ratelimit][:clock_accuracy]
proxy_config[:max_sleep_time_seconds] = node[:swift][:middlewares][:ratelimit][:max_sleep_time_seconds]
proxy_config[:log_sleep_time_seconds] = node[:swift][:middlewares][:ratelimit][:log_sleep_time_seconds]
proxy_config[:rate_buffer_seconds] = node[:swift][:middlewares][:ratelimit][:rate_buffer_seconds]
proxy_config[:account_ratelimit] = node[:swift][:middlewares][:ratelimit][:account_ratelimit]
proxy_config[:account_whitelist] = node[:swift][:middlewares][:ratelimit][:account_whitelist]
proxy_config[:account_blacklist] = node[:swift][:middlewares][:ratelimit][:account_blacklist]
proxy_config[:container_ratelimit_size] = node[:swift][:middlewares][:ratelimit][:container_ratelimit_size]
proxy_config[:lookup_depth] = node[:swift][:middlewares][:cname_lookup][:lookup_depth]
proxy_config[:storage_domain] = node[:swift][:middlewares][:cname_lookup][:storage_domain]
proxy_config[:storage_domain_remap] = node[:swift][:middlewares][:domain_remap][:storage_domain]
proxy_config[:path_root] = node[:swift][:middlewares][:domain_remap][:path_root]
proxy_config[:protocol] = swift_protocol
proxy_config[:ssl_enabled] = node[:swift][:ssl][:enabled]
proxy_config[:ssl_certfile] = node[:swift][:ssl][:certfile]
proxy_config[:ssl_keyfile] = node[:swift][:ssl][:keyfile]
proxy_config[:rabbit_settings] = fetch_rabbitmq_settings
proxy_config[:max_containers_per_extraction] = node[:swift][:middlewares][:bulk][:max_containers_per_extraction]
proxy_config[:max_failed_extractions] = node[:swift][:middlewares][:bulk][:max_failed_extractions]
proxy_config[:max_deletes_per_request] = node[:swift][:middlewares][:bulk][:max_deletes_per_request]
proxy_config[:max_failed_deletes] = node[:swift][:middlewares][:bulk][:max_failed_deletes]
proxy_config[:yield_frequency] = node[:swift][:middlewares][:bulk][:yield_frequency]

cross_domain_policy     = node[:swift][:middlewares][:crossdomain][:cross_domain_policy]
# make sure that cross_domain_policy value fits the required format
# see http://docs.openstack.org/developer/swift/crossdomain.html
cross_domain_policy_l = cross_domain_policy.split("\n").each_with_index.map do |line,index|
  line = "\t" + line unless index == 0
  line
end
proxy_config[:cross_domain_policy] = cross_domain_policy_l.join("\n")

if node[:platform_family] == "rhel"
  pkg_list = %w{curl memcached python-dns}
else
  pkg_list = %w{curl memcached python-dnspython}
end

pkg_list.each do |pkg|
  package pkg
end

if %w(rhel suse).include?(node[:platform_family])
  package "openstack-swift-proxy"
else
  package "swift-proxy"
end

if node[:swift][:middlewares][:s3][:enabled]
  if %w(rhel suse).include?(node[:platform_family])
    package "python-swift3"
  else
    package "swift-plugin-s3"
  end
end

# enable ceilometer middleware if ceilometer is configured
ceilometermiddleware_enabled = node.roles.include? "ceilometer-swift-proxy-middleware"
# unless rabbitmq is secured (see lp#1673738) or is using durable queues
ceilometermiddleware_should_be_disabled = proxy_config[:rabbit_settings][:use_ssl] ||
  proxy_config[:rabbit_settings][:durable_queues]

if ceilometermiddleware_enabled && ceilometermiddleware_should_be_disabled
  Chef::Log.warn("Disabling ceilometer swift-proxy middleware")
end

ceilometer_swift_enabled = {
  "enabled" => ceilometermiddleware_enabled && !ceilometermiddleware_should_be_disabled
}

node.set[:swift] ||= {}
node.set[:swift][:middlewares] ||= {}
if node[:swift][:middlewares]["ceilometer"] != ceilometer_swift_enabled
  node.set[:swift][:middlewares]["ceilometer"] = ceilometer_swift_enabled
  dirty = true
end

if node[:swift][:middlewares]["ceilometer"]["enabled"]
  package "python-ceilometermiddleware"
end

case proxy_config[:auth_method]
   when "swauth"
     package "python-swauth"
     proxy_config[:admin_key] =node[:swift][:cluster_admin_pw]

   when "keystone"
     keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)

     package "python-keystonemiddleware"
     package "python-keystoneclient"

     proxy_config[:keystone_settings] = keystone_settings
     proxy_config[:reseller_prefix] = node[:swift][:reseller_prefix]
     proxy_config[:keystone_delay_auth_decision] = node["swift"]["keystone_delay_auth_decision"]

     crowbar_pacemaker_sync_mark "wait-swift_register" if ha_enabled

     register_auth_hash = { user: keystone_settings["admin_user"],
                            password: keystone_settings["admin_password"],
                            tenant: keystone_settings["admin_tenant"] }

     keystone_register "swift proxy wakeup keystone" do
       protocol keystone_settings["protocol"]
       insecure keystone_settings["insecure"]
       host keystone_settings["internal_url_host"]
       port keystone_settings["admin_port"]
       auth register_auth_hash
       action :wakeup
     end

     # ResellerAdmin is used by swift (see reseller_admin_role option)
     role = "ResellerAdmin"
     keystone_register "add #{role} role for swift" do
       protocol keystone_settings["protocol"]
       insecure keystone_settings["insecure"]
       host keystone_settings["internal_url_host"]
       port keystone_settings["admin_port"]
       auth register_auth_hash
       role_name role
       action :add_role
     end

     keystone_register "register swift user" do
       protocol keystone_settings["protocol"]
       insecure keystone_settings["insecure"]
       host keystone_settings["internal_url_host"]
       port keystone_settings["admin_port"]
       auth register_auth_hash
       user_name keystone_settings["service_user"]
       user_password keystone_settings["service_password"]
       tenant_name keystone_settings["service_tenant"]
       action :add_user
     end

     keystone_register "give swift user access" do
       protocol keystone_settings["protocol"]
       insecure keystone_settings["insecure"]
       host keystone_settings["internal_url_host"]
       port keystone_settings["admin_port"]
       auth register_auth_hash
       user_name keystone_settings["service_user"]
       tenant_name keystone_settings["service_tenant"]
       role_name "admin"
       action :add_access
     end

     keystone_register "register swift service" do
       protocol keystone_settings["protocol"]
       insecure keystone_settings["insecure"]
       host keystone_settings["internal_url_host"]
       auth register_auth_hash
       port keystone_settings["admin_port"]
       service_name "swift"
       service_type "object-store"
       service_description "Openstack Swift Object Store Service"
       action :add_service
     end

     keystone_register "register swift-proxy endpoint" do
         protocol keystone_settings["protocol"]
         insecure keystone_settings["insecure"]
         host keystone_settings["internal_url_host"]
         auth register_auth_hash
         port keystone_settings["admin_port"]
         endpoint_service "swift"
         endpoint_region keystone_settings["endpoint_region"]
         endpoint_publicURL "#{swift_protocol}://#{public_host}:"\
                            "#{node[:swift][:ports][:proxy]}/v1/"\
                            "#{node[:swift][:reseller_prefix]}$(project_id)s"
         endpoint_adminURL "#{swift_protocol}://#{admin_host}:"\
                           "#{node[:swift][:ports][:proxy]}/v1/"
         endpoint_internalURL "#{swift_protocol}://#{admin_host}:"\
                              "#{node[:swift][:ports][:proxy]}/v1/"\
                              "#{node[:swift][:reseller_prefix]}$(project_id)s"
         #  endpoint_global true
         #  endpoint_enabled true
        action :add_endpoint_template
     end

     crowbar_pacemaker_sync_mark "create-swift_register" if ha_enabled

   when "tempauth"
     ## uses defaults...
end

if node[:swift][:ssl][:enabled]
  ssl_setup "setting up ssl for swift" do
    generate_certs node[:swift][:ssl][:generate_certs]
    certfile node[:swift][:ssl][:certfile]
    keyfile node[:swift][:ssl][:keyfile]
    group node[:swift][:group]
    fqdn node[:fqdn]
  end
end

## Find other nodes that are swift-auth nodes, and make sure
## we use their memcached!
proxy_config[:memcached_ips] = node_search_with_cache("roles:swift-proxy").map do |x|
  "#{Swift::Evaluator.get_ip_by_type(x, :admin_ip_expr)}:11211"
end.sort

## Create the proxy server configuraiton file
template node[:swift][:proxy_config_file] do
  source "proxy-server.conf.erb"
  mode "0640"
  owner "root"
  group node[:swift][:group]
  variables proxy_config
end

## install a default memcached instsance.
## default configuration is take from: node[:memcached] / [:memory], [:port] and [:user]
if node[:memcached][:listen] != local_ip
  node.set[:memcached][:listen] = local_ip
  dirty = true
end
if node[:memcached][:name] != "swift-proxy"
  node.set[:memcached][:name] = "swift-proxy"
  dirty = true
end

## make sure to fetch ring files from the ring compute node
compute_nodes = node_search_with_cache("roles:swift-ring-compute")
if (!compute_nodes.nil? and compute_nodes.length > 0 and node[:fqdn]!=compute_nodes[0][:fqdn] )
  compute_node_addr  = Swift::Evaluator.get_ip_by_type(compute_nodes[0],:storage_ip_expr)
  log("ring compute found on: #{compute_nodes[0][:fqdn]} using: #{compute_node_addr}") { level :debug }
  %w{container account object}.each { |ring|
    execute "pull #{ring} ring" do
      user node[:swift][:user]
      group node[:swift][:group]
      command "rsync #{node[:swift][:user]}@#{compute_node_addr}::ring/#{ring}.ring.gz ."
      cwd "/etc/swift"
      ignore_failure true
    end
  }
end

ruby_block "Check if ring is present" do
  block do
    Chef::Log.info("Not setting up swift-proxy daemon; ring-compute node hasn't pushed the rings yet.")
  end
  not_if { ::File.exist? "/etc/swift/object.ring.gz" }
end

if node[:swift][:frontend]=="native"
  service "swift-proxy" do
    service_name node[:swift][:proxy][:service_name]
    if %w(rhel suse).include?(node[:platform_family])
      supports status: true, restart: true
    else
      restart_command "stop swift-proxy ; start swift-proxy"
    end
    action [:enable, :start]
    subscribes :restart, resources(template: node[:swift][:config_file]), :immediately
    subscribes :restart, resources(template: node[:swift][:proxy_config_file]), :immediately
    provider Chef::Provider::CrowbarPacemakerService if ha_enabled
    # Do not even try to start the daemon if we don't have the ring yet
    only_if { ::File.exist? "/etc/swift/object.ring.gz" }
  end
elsif node[:swift][:frontend]=="uwsgi"

  service "swift-proxy" do
    service_name node[:swift][:proxy][:service_name]
    supports status: true, restart: true
    action [:disable, :stop]
  end

  directory "/usr/lib/cgi-bin/swift/" do
    owner "root"
    group "root"
    mode 0755
    action :create
    recursive true
  end

  template "/usr/lib/cgi-bin/swift/proxy.py" do
    source "swift-uwsgi-service.py.erb"
    mode 0755
    variables(
      service: "proxy"
    )
  end

  if node[:swift][:ssl][:enabled]
    uwsgi_instances = {
      https: "#{bind_host}:#{bind_port},#{node[:swift][:ssl][:certfile]},#{node[:swift][:ssl][:keyfile]}"
    }
  else
    uwsgi_instances = {
      http: "#{bind_host}:#{bind_port}"
    }
  end

  uwsgi "swift-proxy" do
    options({
      :chdir => "/usr/lib/cgi-bin/swift/",
      :callable => :application,
      :module => :proxy,
      :protocol => swift_protocol,
      :user => :swift,
      :vacuum => true,
      :"no-orphans" => true,
      :"reload-on-rss" => 192,
      :"reload-on-as" => 256,
      :"max-requests" => 2000,
      :"cpu-affinity" => 1,
      :"reload-mercy" => 8,
      :processes => 4,
      :"buffer-size" => 65535,
      :harakiri => 60,
      :log => "/var/log/swift-proxy-uwsgi.log"
    })
    instances (uwsgi_instances)
    service_name "swift-proxy-uwsgi"
  end

  service "swift-proxy-uwsgi" do
    supports status: true, restart: true, start: true
    action :start
    subscribes :restart, "template[/usr/lib/cgi-bin/swift/proxy.py]"
    # Do not even try to start the daemon if we don't have the ring yet
    only_if { ::File.exist? "/etc/swift/object.ring.gz" }
  end

end

if node[:platform_family] == "debian"
  bash "restart swift proxy things" do
    code <<-EOH
EOH
    action :nothing
    subscribes :run, resources(template: node[:swift][:proxy_config_file])
    notifies :restart, resources(service: "memcached-swift-proxy")
    if node[:swift][:frontend]=="native"
      notifies :restart, resources(service: "swift-proxy")
    end
  end
end

if ha_enabled
  log "HA support for swift is enabled"
  include_recipe "swift::proxy_ha"
else
  log "HA support for swift is disabled"
end

unless node["swift"]["proxy_init_done"]
  node.set["swift"]["proxy_init_done"] = true
  dirty = true
end

node.save if dirty
