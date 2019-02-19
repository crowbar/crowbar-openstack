Chef::Log.info "YYYY *************************************** Common *******************************"

cookbook_file "#{node[:octavia][:sudoers_file]}" do
  source "sudoers"
  owner "root"
  group "root"
  mode 0440
end

group 'octavia' do
  group_name node[:octavia][:group]
  system true
end

user "octavia" do
  shell "/bin/bash"
  comment "Octavia user Server"
  gid node[:octavia][:group]
  system true
  supports manage_home: false
end

directory node[:octavia][:octavia_log_dir] do
  owner node[:octavia][:user]
  group node[:octavia][:group]
  recursive true
end

directory "/etc/octavia/certs/private" do
  owner node[:octavia][:user]
  group node[:octavia][:group]
  recursive true
end


# name: octavia-post-configure | set_octavia_quotas | Set Octavia Quotas
#   shell: >
#     openstack quota set {{ octavia_project_name }} \
#     --floating-ips -1 \
#     --networks -1 \
#     --ports -1 \
#     --secgroups -1 \
#     --routers -1 \
#     --subnetpools -1 \
#     --secgroup-rules -1 \
#     --subnets -1 \
#     --fixed-ips -1 \
#     --cores -1 \
#     --instances -1 \
#     --ram -1
#   environment:
#     OS_AUTH_URL: "{{ octavia_auth_endpoint }}"
#     OS_USERNAME: "{{ keystone_admin_user }}"
#     OS_PASSWORD: "{{ keystone_admin_password }}"
#     OS_PROJECT_NAME: "{{ keystone_service_tenant }}"
#     OS_USER_DOMAIN_NAME: "{{ octavia_user_domain_name }}"
#     OS_PROJECT_DOMAIN_NAME: "{{ octavia_project_domain_name }}"
#     OS_ENDPOINT_TYPE: "{{ octavia_endpoint_type }}"
#     OS_REGION_NAME: "{{ octavia_region_name }}"
#     OS_CACERT: "{{ octavia_ca_file }}"
#     OS_IDENTITY_API_VERSION: "3"
#     OS_AUTH_VERSION: "3"
#     OS_INTERFACE: "internal"
#   run_once_per: verb_hosts.OCT_API
