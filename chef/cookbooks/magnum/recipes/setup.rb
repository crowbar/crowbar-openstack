#
# Copyright 2016 SUSE Linux GmbH
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
# Cookbook Name:: magnum
# Recipe:: setup
#

keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)

trustee_domain_name = node["magnum"]["trustee"]["domain_name"]
trustee_domain_admin = node["magnum"]["trustee"]["domain_admin_name"]
trustee_domain_admin_password = node["magnum"]["trustee"]["domain_admin_password"]

insecure = keystone_settings["insecure"] ? "--insecure" : ""
auth_url = "#{keystone_settings["protocol"]}://"\
           "#{keystone_settings["internal_url_host"]}:"\
           "#{keystone_settings["service_port"]}/v3"

domain_env = { "OS_USERNAME"             => keystone_settings["admin_user"],
               "OS_PASSWORD"             => keystone_settings["admin_password"],
               "OS_TENANT_NAME"          => keystone_settings["admin_tenant"],
               "OS_AUTH_URL"             => auth_url,
               "OS_REGION_NAME"          => keystone_settings["endpoint_region"],
               "OS_IDENTITY_API_VERSION" => "3" }

bash "register magnum domain" do
  user "root"
  code <<-EOF
    id=
    eval $(openstack #{insecure} domain create \
        #{trustee_domain_name} \
        --description 'Owns users and projects created by magnum' \
        --or-show -f value -c id)
    TRUSTEE_DOMAIN_ID=$id

    id=
    eval $(openstack #{insecure} user create \
        --domain #{trustee_domain_name} \
        --or-show -f value -c id \
        #{trustee_domain_admin})
    TRUSTEE_DOMAIN_ADMIN_ID=$id

    ret=
    eval $(openstack #{insecure} \
        user set \
        --domain $TRUSTEE_DOMAIN_ID \
        --password #{trustee_domain_admin_password} \
        --description "Manages users and projects created by magnum" \
        #{trustee_domain_admin})
    ret=
    eval $(openstack #{insecure} role add \
        --user $TRUSTEE_DOMAIN_ADMIN_ID \
        --domain $TRUSTEE_DOMAIN_ID admin)
  EOF
  environment domain_env
end

ruby_block "Update node parameters" do
  block do
    openstack_command = "openstack --os-username #{keystone_settings["admin_user"]}"
    openstack_command << " --os-auth-type password --os-identity-api-version 3"
    openstack_command << " --os-password #{keystone_settings["admin_password"]}"
    openstack_command << " --os-tenant-name #{keystone_settings["admin_tenant"]}"
    openstack_command << " --os-auth-url #{keystone_settings["protocol"]}://#{keystone_settings["internal_url_host"]}:#{keystone_settings["service_port"]}/v3/"

    trustee_domain_id = `#{openstack_command} domain show #{trustee_domain_name} -f value -c id`.chomp
    trustee_domain_admin_id = `#{openstack_command} user show #{trustee_domain_admin} -f value -c id --domain #{trustee_domain_name}`.chomp

    node.set[:magnum][:trustee][:domain_id] = trustee_domain_id
    node.set[:magnum][:trustee][:domain_admin_id] = trustee_domain_admin_id

    node.save
  end
end
