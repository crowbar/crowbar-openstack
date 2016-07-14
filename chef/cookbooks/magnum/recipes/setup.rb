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

# Install openstack and magnum client packages
if %w(rhel suse).include?(node[:platform_family])
  ["python-magnumclient", "python-openstackclient"].each do |pkg|
    package pkg
  end
end

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
    # Find domain ID
    id=
    eval $(openstack #{insecure} \
        domain show \
        -f shell --variable id \
        #{trustee_domain_name})
    MAGNUM_DOMAIN_ID=$id

    if [ -z "$MAGNUM_DOMAIN_ID" ]; then
        id=
        eval $(openstack #{insecure} \
            domain create \
            -f shell --variable id \
            --description "Owns users and projects created by magnum" \
            #{trustee_domain_name})
        MAGNUM_DOMAIN_ID=$id
    fi

    [ -n "$MAGNUM_DOMAIN_ID" ] || exit 1

    id=
    eval $(openstack #{insecure} \
        user show #{trustee_domain_admin} \
        -f shell -c id --domain #{trustee_domain_name})
    MAGNUM_DOMAIN_ADMIN_ID=$id

    if [ -z "$MAGNUM_DOMAIN_ADMIN_ID" ]; then
        id=
        eval $(openstack #{insecure} \
            user create \
            --domain #{trustee_domain_name} \
            --or-show -f shell -c id #{trustee_domain_admin})
        MAGNUM_DOMAIN_ADMIN_ID=$id

        openstack #{insecure} \
            user set \
            --password #{trustee_domain_admin_password} \
            --description "Manages users and projects created by magnum" \
            #{trustee_domain_admin}
    fi

    [ -n "$MAGNUM_DOMAIN_ADMIN_ID" ] || exit 1

    # Make domain user as admin for the role
    if ! openstack #{insecure} \
            role list \
            -f csv --column Name \
            --domain $MAGNUM_DOMAIN_ID \
            --user $MAGNUM_DOMAIN_ADMIN_ID \
            | grep -q \"admin\"; then
        openstack #{insecure} \
            role add \
            --user $MAGNUM_DOMAIN_ADMIN_ID \
            --domain $MAGNUM_DOMAIN_ID admin
    fi
  EOF
  environment domain_env
end

ruby_block "Update node parameters" do
  block do
    openstack_command = "openstack --os-username #{keystone_settings["admin_user"]}"
    openstack_command << " --os-auth-type password --os-identity-api-version 3"
    openstack_command << " --os-password #{keystone_settings["admin_password"]}"
    openstack_command << " --os-tenant-name #{keystone_settings["admin_tenant"]}"
    openstack_command << " --os-auth-url #{auth_url}"

    domain_id_cmd = "#{openstack_command} domain show #{trustee_domain_name} -f value -c id"
    trustee_domain_id = `#{domain_id_cmd}`.chomp
    admin_id_cmd = "#{openstack_command} user show #{trustee_domain_admin}"
    admin_id_cmd << " -f value -c id --domain #{trustee_domain_name}"
    trustee_domain_admin_id = `#{admin_id_cmd}`.chomp

    node.set[:magnum][:trustee][:domain_id] = trustee_domain_id
    node.set[:magnum][:trustee][:domain_admin_id] = trustee_domain_admin_id

    node.save
  end
end
