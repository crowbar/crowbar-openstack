#
# Cookbook Name:: kong
# Recipe:: default
#
# Copyright 2011, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

package "python-httplib2"
package "python-nose"
package "python-unittest2"

# Download and unpack tempest tarball

tarball_url = node[:kong][:tempest_tarball]
filename = tarball_url.split('/').last
dst_dir = "/opt"

remote_file tarball_url do
  source tarball_url
  path "#{dst_dir}/#{filename}"
  action :create_if_missing
end

execute "tar" do
  cwd dst_dir
  command "tar -xf #{dst_dir}/#{filename}"
  action :run
end

bash "remove_commit-hash_from_path" do
  cwd dst_dir
  code <<-EOH
mv openstack-tempest-* tempest
EOH
  not_if { ::File.exists?("#{dst_dir}/tempest") }
end

keystones = search(:node, "roles:keystone-server") || []
if keystones.length > 0
  keystone = keystones[0]
  keystone = node if keystone.name == node.name
else
  keystone = node
end

keystone_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(keystone_address, "admin").address if keystone_address.nil?

keystone_port = keystone[:keystone][:api][:service_port]

comp_admin_user = keystone[:keystone][:admin][:username]
comp_admin_pass = keystone[:keystone][:admin][:password]
comp_admin_tenant = keystone[:keystone][:admin][:tenant]

comp_user = keystone[:keystone][:default][:username]
comp_pass = keystone[:keystone][:default][:password]
comp_tenant = keystone[:keystone][:default][:tenant]

img_user = comp_admin_user
img_pass = comp_admin_pass
img_tenant = comp_admin_tenant

alt_comp_user = "crowbar2"
alt_comp_pass = "crowbar2"
alt_comp_tenant = "service"

keystone_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(keystone, "admin").address if keystone_address.nil?
keystone_token = keystone[:keystone][:service][:token]
keystone_admin_port = keystone[:keystone][:api][:admin_port]

glances = search(:node, "roles:glance-server") || []
if glances.length > 0
  glance = glances[0]
  glance = node if glance.name == node.name
else
  glance = node
end

glance_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(glance, "admin").address if glance_address.nil?

glance_port = glance[:glance][:api][:bind_port]

glance_attrs = " -H #{glance_address}" +
               " -p #{glance_port}" +
               " -I #{comp_admin_user}" +
               " -K #{comp_admin_pass}" +
               " -T #{comp_admin_tenant}" + 
               " -N http://#{keystone_address}:#{keystone_port}/v2.0"

image_ref = `ssh root@#{glance_address} glance #{glance_attrs} index|grep ami|awk '{print \$1}'`.strip()

alt_image_ref = image_ref
flavor_ref = "1"
alt_flavor_ref = "1"

keystone_register "kong tempest wakeup keystone" do
  host keystone_address
  port keystone_admin_port
  token keystone_token
  action :wakeup
end

keystone_register "register second non-admin user crowbar2" do
  host keystone_address
  port keystone_admin_port
  token keystone_token
  user_name alt_comp_user
  user_password alt_comp_pass 
  tenant_name alt_comp_tenant
  action :add_user
end

template "#{dst_dir}/tempest/etc/tempest.conf" do
  source "tempest.conf.erb"
  mode 0644
  variables(
           :key_host => keystone_address,
           :key_port => keystone_port,
           :comp_user => comp_user,
           :comp_pass => comp_pass,
           :comp_tenant => comp_tenant,
           :alt_comp_user => alt_comp_user,
           :alt_comp_pass => alt_comp_pass,
           :alt_comp_tenant => alt_comp_tenant,
           :img_host => glance_address,
           :img_port => glance_port,
           :image_ref => image_ref,
           :alt_image_ref => alt_image_ref,
           :flavor_ref => flavor_ref,
           :alt_flavor_ref => alt_flavor_ref,
           :img_user => img_user,
           :img_pass => img_pass,
           :img_tenant => img_tenant,
           :comp_admin_user => comp_admin_user,
           :comp_admin_pass => comp_admin_pass,
           :comp_admin_tenant => comp_admin_tenant 
	   )
end

