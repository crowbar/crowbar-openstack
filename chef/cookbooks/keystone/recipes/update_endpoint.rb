# Copyright 2018 SUSE Linux GmbH
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

ha_enabled = node[:keystone][:ha][:enabled]

if node[:keystone].key?(:endpoint)
  endpoint_protocol = node[:keystone][:endpoint][:protocol]
  endpoint_insecure = node[:keystone][:endpoint][:insecure]
  endpoint_port = node[:keystone][:endpoint][:port]

  endpoint_changed = endpoint_protocol != node[:keystone][:api][:protocol] ||
    endpoint_insecure != node[:keystone][:ssl][:insecure] ||
    endpoint_port != node[:keystone][:api][:admin_port]

  # Will be reset on next chef run
  node.default[:keystone][:endpoint_changed] = endpoint_changed

  endpoint_needs_update = endpoint_changed &&
    node[:keystone][:bootstrap] &&
    # Do not try to update keystone endpoint during upgrade, when keystone is not
    # running yet ("done_os_upgrade" is present when first chef-client run is
    # executed at the end of upgrade)
    node["crowbar_upgrade_step"] != "done_os_upgrade"
else
  endpoint_needs_update = false
end
endpoint_host = CrowbarHelper.get_host_for_admin_url(node, ha_enabled)

use_ssl = node[:keystone][:api][:protocol] == "https"
public_host = CrowbarHelper.get_host_for_public_url(node, use_ssl, ha_enabled)
register_auth_hash = { user: node[:keystone][:admin][:username],
                       password: node[:keystone][:admin][:password],
                       project: node[:keystone][:admin][:project] }

# In compile phase, update the internal keystone endpoint if necessary.
# Do this before the haproxy and apache configs are updated, otherwise the old
# endpoint will become invalid too early.
keystone_register "update keystone internal endpoint" do
  protocol endpoint_protocol
  insecure endpoint_insecure
  host endpoint_host
  port endpoint_port
  auth register_auth_hash
  endpoint_service "keystone"
  endpoint_region node[:keystone][:api][:region]
  endpoint_url KeystoneHelper.internal_auth_url(node, endpoint_host)
  endpoint_interface "internal"
  action :nothing
  only_if do
    endpoint_needs_update &&
      (!ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node))
  end
end.run_action(:update_one_endpoint)

# Update variables for use in converge-phase endpoint updates
endpoint_protocol = node[:keystone][:api][:protocol]
endpoint_insecure = node[:keystone][:ssl][:insecure]
endpoint_port = node[:keystone][:api][:admin_port]

ruby_block "Prepare haproxy and apache2 for new keystone endpoints" do
  block {}
  if ha_enabled
    notifies :create, resources(template: node[:haproxy][:platform][:config_file]), :immediately
    notifies :reload, resources(service: "haproxy"), :immediately
  end
  notifies :create, resources(ruby_block: "set origin for apache2 restart"), :immediately
  notifies :reload, resources(service: "apache2"), :immediately
  only_if { endpoint_needs_update }
end

keystone_register "wakeup keystone after service reload" do
  protocol endpoint_protocol
  insecure endpoint_insecure
  host endpoint_host
  port endpoint_port
  auth register_auth_hash
  retries 10
  retry_delay 10
  action :wakeup
end

# Wait until all nodes have refreshed haproxy and apache before trying to use
# the new internal endpoint to update the rest of the endpoints
crowbar_pacemaker_sync_mark "sync-keystone_update_endpoints" if ha_enabled

crowbar_pacemaker_sync_mark "wait-keystone_update_endpoints" if ha_enabled

# Update keystone endpoints (in case we switch http/https this will update the
# endpoints to the correct ones). This needs to be done _before_ we switch
# protocols on the keystone api.
keystone_register "update keystone endpoint" do
  protocol endpoint_protocol
  insecure endpoint_insecure
  host endpoint_host
  port endpoint_port
  auth register_auth_hash
  endpoint_service "keystone"
  endpoint_region node[:keystone][:api][:region]
  endpoint_adminURL KeystoneHelper.admin_auth_url(node, endpoint_host)
  endpoint_publicURL KeystoneHelper.public_auth_url(node, public_host)
  endpoint_internalURL KeystoneHelper.internal_auth_url(node, endpoint_host)
  action :update_endpoint
  # Do not try to update keystone endpoint during upgrade, when keystone is not running yet
  # ("done_os_upgrade" is present when first chef-client run is executed at the end of upgrade)
  only_if do
    endpoint_needs_update &&
      (!ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node))
  end
end

crowbar_pacemaker_sync_mark "create-keystone_services" if ha_enabled
