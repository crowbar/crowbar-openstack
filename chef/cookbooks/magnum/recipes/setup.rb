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

keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)

magnum_domain_name = node["magnum"]["trustee"]["domain_name"]
magnum_domain_admin = node["magnum"]["trustee"]["domain_admin_name"]
magnum_domain_admin_pass = node["magnum"]["trustee"]["domain_admin_password"]

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

openstack_command = "openstack --os-username #{keystone_settings["admin_user"]}"
openstack_command << " --os-auth-type password --os-identity-api-version 3"
openstack_command << " --os-password #{keystone_settings["admin_password"]}"
openstack_command << " --os-tenant-name #{keystone_settings["admin_tenant"]}"
openstack_command << " --os-auth-url #{auth_url} #{insecure}"

ha_enabled = node[:magnum][:ha][:enabled]

crowbar_pacemaker_sync_mark "wait-magnum_setup_domain" if ha_enabled

create_magnum_domain = "#{openstack_command} domain create -f value -c id"
create_magnum_domain << " --description 'Owns users and projects created by magnum'"
create_magnum_domain << " --or-show"
create_magnum_domain << " #{magnum_domain_name}"

unless node["magnum"]["trustee"]["domain_id"] && node["magnum"]["trustee"]["domain_admin_id"]
  magnum_domain_id = Mixlib::ShellOut.new(create_magnum_domain).run_command.stdout.chomp

  if magnum_domain_id && !magnum_domain_id.empty?
    create_magnum_domain_admin = "#{openstack_command} user create --domain #{magnum_domain_name}"
    create_magnum_domain_admin << " --description 'Manages users and projects created by magnum'"
    create_magnum_domain_admin << " --password #{magnum_domain_admin_pass}"
    create_magnum_domain_admin << " --or-show -f value -c id #{magnum_domain_admin}"

    magnum_domain_admin_id = Mixlib::ShellOut.new(create_magnum_domain_admin).run_command.stdout.chomp

    if magnum_domain_admin_id && !magnum_domain_admin_id.empty?
      check_magnum_domain_role = "#{openstack_command} role assignment list -f csv --column Role"
      check_magnum_domain_role << " --domain #{magnum_domain_id} --user #{magnum_domain_admin_id} --names"

      magnum_domain_role = Mixlib::ShellOut.new(check_magnum_domain_role).run_command.stdout

      unless magnum_domain_role.include?('"admin"')
        create_magnum_domain_role = "#{openstack_command} role add --user #{magnum_domain_admin_id}"
        create_magnum_domain_role << " --domain #{magnum_domain_id} admin"
        Mixlib::ShellOut.new(create_magnum_domain_role).run_command
      end

      node.set["magnum"]["trustee"]["domain_id"] = magnum_domain_id
      node.set["magnum"]["trustee"]["domain_admin_id"] = magnum_domain_admin_id
      node.save
    end
  end
end

crowbar_pacemaker_sync_mark "create-magnum_setup_domain" if ha_enabled
