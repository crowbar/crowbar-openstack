
# Copyright (c) 2019 SUSE Linux, GmbH.
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
override[:octavia][:user]="octavia"
override[:octavia][:group]="octavia"

defautl[:octavia][:octavia_log_dir] = "/var/log/octavia"
defautl[:octavia][:octavia_bin_dir] = "octavia" #TODO: Check this value!
defautl[:octavia][:restart_hold] = "100ms"

#
# default[:octavia][:debug] = false

#TODO: octavia_defaults
# default[:octavia][:mysql][:host]
# default[:octavia][:mysql][:octavia_user]
# default[:octavia][:mysql][:octavia_password]
# default[:octavia][:mysql][:use_tls]
# default[:octavia][:mysql][:ca]
#
# keystone:
# default[:octavia][:keystone][:admin_tenant: "{{ KEY_API.vars.keystone_admin_tenant }}"
# default[:octavia][:keystone][:service_tenant: "{{ KEY_API.vars.keystone_service_tenant }}"
# default[:octavia][:keystone][:auth_uri: "{{ OCT_API.consumes_KEY_API.vips.private[0].url }}"
# default[:octavia][:keystone][:identity_uri: "{{ OCT_API.consumes_KEY_API.vips.private[0].url }}"
# default[:octavia][:keystone][:endpoint: "{{ OCT_API.consumes_KEY_API.vips.private[0].url }}/v3"
# default[:octavia][:keystone][:octavia_admin_user: "{{ OCT_API.consumes_KEY_API.vars.keystone_octavia_user }}"
# default[:octavia][:keystone][:octavia_admin_password: "{{ OCT_API.consumes_KEY_API.vars.keystone_octavia_password | quote }}"
# default[:octavia][:keystone][:octavia_project_name: "{{ OCT_API.consumes_KEY_API.vars.octavia_admin_project }}"
# default[:octavia][:keystone][:admin_user: "{{ KEY_API.vars.keystone_admin_user }}"
# default[:octavia][:keystone][:admin_password: "{{ KEY_API.vars.keystone_admin_pwd | quote }}"
# default[:octavia][:keystone][:default_domain_name: "{{ KEY_API.vars.keystone_default_domain }}"
# default[:octavia][:keystone][:admin_role: "{{ KEY_API.vars.keystone_admin_role }}"
#
# neutron:
# default[:octavia][:neutron][:admin_user: "{{ OCT_API.consumes_KEY_API.vars.keystone_neutron_user }}"
# default[:octavia][:neutron][:admin_password: "{{ OCT_API.consumes_KEY_API.vars.keystone_neutron_password | quote }}"
# default[:octavia][:neutron][:endpoint: "{{ OCT_API.consumes_NEU_SVR.vips.private[0].url }}"
#
# nova:
# default[:octavia][:nova][:endpoint: "{{ OCT_API.consumes_NOV_API.vips.private[0].url }}/v2.1"
#
# rabbit:
# default[:octavia][:rabbit][:members: "{{ OCT_API.consumes_FND_RMQ.members.private }}"
# default[:octavia][:rabbit][:userid: "{{ OCT.consumes_FND_RMQ.vars.accounts.octavia.username }}"
# default[:octavia][:rabbit][:password: "{{ OCT.consumes_FND_RMQ.vars.accounts.octavia.password }}"
# default[:octavia][:rabbit][:use_ssl: "{{ OCT.consumes_FND_RMQ.members.private[0].use_tls }}"
#
# health_manager:
# default[:octavia][:health_manager][:members: "{{ OCT_API.consumes_OCT_HMX.members.private }}"
# default[:octavia][:health_manager][:heartbeat_key: "{{ OCT_API.consumes_OCT_HMX.vars.heartbeat_key }}"

# octavia_db_connection: "mysql+pymysql://{{ mysql.octavia_user }}:{{ mysql.octavia_password | urlencode }}@{{ mysql.host }}/octavia{% if mysql.use_tls %}{{ mysql.ca }}{% endif %}"
#
# octavia_endpoint_type: "internalURL"
#
# installation_directory: "/usr/share"
# octavia_log_file_group: "adm"
# keystone_service_tenant: "{{ keystone.service_tenant }}"
# keystone_admin_tenant: "{{ keystone.admin_tenant }}"
# keystone_admin_user: "{{ keystone.admin_user }}"
# keystone_admin_password: "{{ keystone.admin_password }}"
# keystone_endpoint: "{{ keystone.endpoint }}"
# neutron_endpoint: "{{ neutron.endpoint }}"
# nova_endpoint: "{{ nova.endpoint }}"
# keystone_default_domain: "{{ keystone.default_domain_name }}"
# octavia_common_rundir: "/var/run/octavia"
# octavia_project_domain_name: "{{ keystone.default_domain_name }}"
# octavia_user_domain_name: "{{ keystone.default_domain_name }}"
# octavia_project_name: "{{ keystone.octavia_project_name }}"
# octavia_neutron_admin_role: "neutron_admin"
#
# octavia_region_name: "{{ OCT.regions | first }}"
#
# ## [DEFAULT]
# octavia_bind_host: "{% if host.bind.OCT_API is defined %}{{ host.bind.OCT_API.internal.ip_address }}{% endif %}"
# octavia_bind_port: "9876"
#
# ## [health_manager]
# octavia_healthmanager_bind_host: "{{ octavia_bind_host }}"
# octavia_healthmanager_port: "5555"
# octavia_healthmanager_hosts: "{% for x in health_manager.members %}{{ x.ip_address }}:{{ x.port }}{%if not loop.last %},{% endif %}{% endfor %}"
# octavia_heartbeat_key: "{{ health_manager.heartbeat_key }}"
#
# ### RabbitMQ
# octavia_rabbit_hosts: "{% for x in rabbit.members %}{{ x.host }}:{{ x.port }}{%if not loop.last %},{% endif %}{% endfor %}"
# octavia_rabbit_userid: "{{ rabbit.userid }}"
# octavia_rabbit_password: "{{ rabbit.password }}"
# octavia_rabbit_use_ssl: "{{ rabbit.use_ssl }}"
#
# ## [keystone_authtoken]
# octavia_auth_endpoint: "{{ keystone.endpoint }}"
# octavia_identity_uri: "{{ keystone.identity_uri }}"
# octavia_admin_user: "{{ keystone.octavia_admin_user }}"
# octavia_admin_password: "{{ keystone.octavia_admin_password }}"
# octavia_ca_file: "{{ trusted_ca_bundle }}"
#
# ## [certificates]
# octavia_ca_private_key_passphrase: "foobar"
# octavia_ca_private_key: "{{ octavia_conf_dir }}/certs/private/cakey.pem"
# octavia_ca_certificate: "{{ octavia_conf_dir }}/certs/cacert.pem"
#
# ## [haproxy_amphora]
# octavia_server_ca: "{{ octavia_conf_dir}}/certs/cacert.pem"
# octavia_client_ca: "{{ octavia_conf_dir}}/certs/client_ca.pem"
# octavia_client_cert: "{{ octavia_conf_dir}}/certs/client.pem"
# octavia_key_path: "{{ octavia_conf_dir}}/.ssh/octavia_ssh_key"
# # haproxy_template = /var/lib/octavia/custom_template
# # The following may need to be an absolute location:
# # base_log_dir = /logs
#
# ## [barbican]
# neutron_admin_user: "{{ neutron.admin_user }}"
# neutron_admin_password: "{{ neutron.admin_password }}"
#
# octavia_mgmt_net: "{{ config_data.OCT.amp_network_name }}"
# octavia_mgmt_sec_group: "lb-mgmt-sec-group"
# octavia_nova_flavor_name: "m1.lbaas.amphora"
# # This is set later once the image is unpacked
# octavia_amp_image_id: ""
# octavia_amp_image_tag: "amphora"
#
# octavia_user_domain_name: "{{ keystone.default_domain_name }}"
# octavia_project_domain_name: "{{ keystone.default_domain_name }}"
#
# ## variables needed by _write_conf.yml
# write_conf_file_owner: "{{ octavia_user }}"
# write_conf_file_group: "{{ octavia_group }}"
#
# # tls stuff
# tls_temp_dir: "/tmp/ardana_octavia_tls/"
# tls_req_dir: "/tmp/ardana_octavia_tls/"
# tls_req_file: "ardana-octavia-req"
# tls_certs_dir: "/tmp/ardana_octavia_certs/"
#
# tls_ca_cert_file: "cacert.pem"
# tls_ca_key_file: "cakey.pem"
# tls_index_file: "{{ tls_temp_dir }}/indext.txt"
# tls_serial_file: "{{ tls_temp_dir }}/serial"
#
# tls_cert_file: "{{ tls_certs_dir }}/client.pem"
#
# tls_server_ca_file: "serverca_01.pem"
# tls_server_ca_key_file: "servercakey.pem"
