#
# Copyright 2020, SUSE
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

ses_config = SesHelper.ses_settings

return if ses_config.nil? || ses_config.fetch("radosgw_urls", []).empty?

ha_enabled = node[:keystone][:ha][:enabled]

keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)

register_auth_hash = { user: keystone_settings["admin_user"],
                       password: keystone_settings["admin_password"],
                       project: keystone_settings["admin_project"] }

keystone_register "register RadosGW service" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  auth register_auth_hash
  port keystone_settings["admin_port"]
  service_name "swift"
  service_type "object-store"
  service_description "RadosGW Service"
  action :add_service
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

keystone_register "register RadosGW endpoint" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  auth register_auth_hash
  port keystone_settings["admin_port"]
  endpoint_service "swift"
  endpoint_region keystone_settings["endpoint_region"]
  endpoint_publicURL ses_config["radosgw_urls"].first
  endpoint_adminURL ses_config["radosgw_urls"].first
  endpoint_internalURL ses_config["radosgw_urls"].first
  action :add_endpoint
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
end
