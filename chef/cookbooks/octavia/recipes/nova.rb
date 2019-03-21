require "chef/mixin/shell_out"

ha_enabled = node[:octavia][:ha][:enabled]

package "openstack-octavia-amphora-image-x86_64"

keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)

env = "OS_USERNAME='#{keystone_settings["service_user"]}' "
env << "OS_PASSWORD='#{keystone_settings["service_password"]}' "
env << "OS_PROJECT_NAME='#{keystone_settings["service_tenant"]}' "
env << "OS_AUTH_URL='#{keystone_settings["internal_auth_url"]}' "
env << "OS_REGION_NAME='#{keystone_settings["endpoint_region"]}' "
env << "OS_INTERFACE=internal "
env << "OS_USER_DOMAIN_NAME=Default "
env << "OS_PROJECT_DOMAIN_NAME=Default "
env << "OS_IDENTITY_API_VERSION=3"

ssl_insecure = true #TODO: add entry to default and templates (check neutorn)

cmd = "#{env} openstack #{ssl_insecure ? "--insecure" : ""}"

sec_group = node[:octavia][:amphora][:sec_group]
project_name =  node[:octavia][:amphora][:project]


execute "create_security_group" do
  command "#{cmd} security group create #{sec_group} --project #{project_name} "\
    "--description \"Octavia Management Security Group\""
  not_if "out=$(#{cmd} security group list); [ $? != 0 ] || echo ${out} | grep -q ' #{sec_group} '"
  retries 5
  retry_delay 10
  action :run
end

execute "add_amphora_port_to_amphora_security_group" do
  command "#{cmd} security group rule create --protocol tcp --dst-port 9443:9443 #{sec_group}"
  not_if "out=$(#{cmd} security group show #{sec_group}); [ $? != 0 ] || echo ${out} | " \
    "grep -q \"'9443'\""
  retries 5
  retry_delay 10
  action :run
end

execute "add_ssh_to_amphora_security_group" do
  command "#{cmd} security group rule create --protocol tcp --dst-port 22:22 #{sec_group}"
  not_if "out=$(#{cmd} security group show #{sec_group}); [ $? != 0 ] || echo ${out} | " \
    "grep -q \"'22'\""
  only_if { node[:octavia][:amphora][:ssh_access] }
  retries 5
  retry_delay 10
  action :run
end

execute "add_icmp_to_amphora_security_group" do
  command "#{cmd} security group rule create --protocol icmp #{sec_group}"
  not_if "out=$(#{cmd} security group show #{sec_group}); [ $? != 0 ] || echo ${out} | " \
    "grep -q \"'icmp'\""
  retries 5
  retry_delay 10
  action :run
end

flavor = node[:octavia][:amphora][:flavor]

execute "create_amphora_flavor" do
  command "#{cmd} flavor create --public --ram 1024 --disk 2 --vcpus 1 #{flavor}"
  not_if "out=$(#{cmd} flavor list); [ $? != 0 ] || echo ${out} | grep -q ' #{flavor} '"
  retries 5
  retry_delay 10
  action :run
end

package = "openstack-octavia-amphora-image-x86_64"
image_tag = node[:octavia][:amphora][:image_tag]


execute "create_amphora_flavor" do
  command "#{cmd} image create --disk-format qcow2 --container-format bare "\
    "--file $(rpm -ql #{package} | grep qcow2 | head -n 1) #{image_tag}"
  not_if "out=$(#{cmd} image list); [ $? != 0 ] || echo ${out} | grep -q ' #{image_tag} '"
  retries 5
  retry_delay 10
  action :run
end
