
# Copyright (c) 2011 Dell Inc.
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

case node[:platform_family]
when "rhel", "suse"
  default[:keystone][:service_name] = "openstack-keystone"
else
  default[:keystone][:service_name] = "keystone"
end

default[:keystone][:user] = "keystone"
default[:keystone][:group] = "keystone"

default[:keystone][:debug] = false
default[:keystone][:frontend] = "apache"
default[:keystone][:domain_specific_drivers] = false
default[:keystone][:domain_config_dir] = "/etc/keystone/domains"
default[:keystone][:config_file] = "/etc/keystone/keystone.conf.d/100-keystone.conf"

default[:keystone][:policy_file] = "policy.json"

default[:keystone][:db][:database] = "keystone"
default[:keystone][:db][:user] = "keystone"
default[:keystone][:db][:password] = "" # Set by Recipe

default[:keystone][:api][:protocol] = "http"
default[:keystone][:api][:service_port] = 5000
default[:keystone][:api][:admin_port] = 35357
default[:keystone][:api][:admin_host] = "0.0.0.0"
default[:keystone][:api][:api_host] = "0.0.0.0"
default[:keystone][:api][:version] = "2.0"
default[:keystone][:api][:region] = "RegionOne"

default[:keystone][:identity][:driver] = "sql"
default[:keystone][:assignment][:driver] = "sql"

default[:keystone][:sql][:idle_timeout] = 30

default[:keystone][:signing][:token_format] = "UUID"
default[:keystone][:signing][:certfile] = "/etc/keystone/ssl/certs/signing_cert.pem"
default[:keystone][:signing][:keyfile] = "/etc/keystone/ssl/private/signing_key.pem"
default[:keystone][:signing][:ca_certs] = "/etc/keystone/ssl/certs/ca.pem"

default[:keystone][:ssl][:certfile] = "/etc/keystone/ssl/certs/signing_cert.pem"
default[:keystone][:ssl][:keyfile] = "/etc/keystone/ssl/private/signing_key.pem"
default[:keystone][:ssl][:generate_certs] = false
default[:keystone][:ssl][:insecure] = false
default[:keystone][:ssl][:ca_certs] = "/etc/keystone/ssl/certs/ca.pem"

default[:keystone][:ldap][:url] = "ldap://localhost"
default[:keystone][:ldap][:user] = "dc=Manager,dc=example,dc=com"
default[:keystone][:ldap][:password] = ""
default[:keystone][:ldap][:suffix] = "cn=example,cn=com"
default[:keystone][:ldap][:page_size] = 0
default[:keystone][:ldap][:alias_dereferencing] = "default"
default[:keystone][:ldap][:query_scope] = "one"

default[:keystone][:ldap][:user_tree_dn] = ""
default[:keystone][:ldap][:user_filter] = ""
default[:keystone][:ldap][:user_objectclass] = "inetOrgPerson"
default[:keystone][:ldap][:user_id_attribute] = "cn"
default[:keystone][:ldap][:user_name_attribute] = "sn"
default[:keystone][:ldap][:user_description_attribute] = "description"
default[:keystone][:ldap][:user_mail_attribute] = "mail"
default[:keystone][:ldap][:user_pass_attribute] = "userPassword"
default[:keystone][:ldap][:user_enabled_attribute] = "enabled"
default[:keystone][:ldap][:user_enabled_invert] = false
default[:keystone][:ldap][:user_enabled_mask] = 0
default[:keystone][:ldap][:user_enabled_default] = "True"
default[:keystone][:ldap][:user_attribute_ignore] = "default_project_id"
default[:keystone][:ldap][:user_default_project_id_attribute] = ""
default[:keystone][:ldap][:user_enabled_emulation] = false
default[:keystone][:ldap][:user_enabled_emulation_dn] = ""
default[:keystone][:ldap][:user_enabled_emulation_use_group_config] = false
default[:keystone][:ldap][:user_additional_attribute_mapping] = ""

default[:keystone][:ldap][:group_tree_dn] = ""
default[:keystone][:ldap][:group_filter] = ""
default[:keystone][:ldap][:group_objectclass] = "groupOfNames"
default[:keystone][:ldap][:group_id_attribute] = "cn"
default[:keystone][:ldap][:group_name_attribute] = "ou"
default[:keystone][:ldap][:group_member_attribute] = "member"
default[:keystone][:ldap][:group_members_are_ids] = false
default[:keystone][:ldap][:group_desc_attribute] = "description"
default[:keystone][:ldap][:group_additional_attribute_mapping] = ""
default[:keystone][:ldap][:group_ad_nesting] = false
default[:keystone][:ldap][:use_pool] = true
default[:keystone][:ldap][:pool_size] = 10
default[:keystone][:ldap][:pool_retry_max] = 3
default[:keystone][:ldap][:pool_retry_delay] = 0.1
default[:keystone][:ldap][:pool_connection_timeout] = -1
default[:keystone][:ldap][:pool_connection_lifetime] = 600
default[:keystone][:ldap][:use_auth_pool] = true
default[:keystone][:ldap][:auth_pool_size] = 100
default[:keystone][:ldap][:auth_pool_connection_lifetime] = 60

default[:keystone][:ha][:enabled] = false
# Ports to bind to when haproxy is used for the real ports
default[:keystone][:ha][:ports][:service_port] = 5500
default[:keystone][:ha][:ports][:admin_port] = 5501
# Pacemaker bits
#default[:keystone][:ha][:agent] = "ocf:openstack:keystone"
default[:keystone][:ha][:agent] = "service:openstack-keystone"
default[:keystone][:ha][:op][:monitor][:interval] = "10s"
# Pacemaker Keystone fernet service
default[:keystone][:ha][:fernet][:agent] = "ocf:heartbeat:symlink"
default[:keystone][:ha][:fernet][:op][:monitor][:interval] = "10s"
