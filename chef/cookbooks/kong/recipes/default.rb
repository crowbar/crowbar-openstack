#
# Cookbook Name:: kong
# Recipe:: default
#
# Copyright 2011, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

package "python-virtualenv"
package "python-argparse"
package "python-anyjson"
package "python-httplib2"
package "python-nose"
package "python-amqplib"
package "python-pika"
package "python-unittest2"
package "pep8"
package "pylint"


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
mv openstack-tempest-* openstack-tempest
EOH
end

comp_admin_user = node[:keystone][:admin][:username]
comp_admin_pass = node[:keystone][:admin][:password]
comp_admin_tenant = node[:keystone][:admin][:tenant]

comp_user = node[:keystone][:default][:username]
comp_pass = node[:keystone][:default][:password]
comp_tenant = node[:keystone][:default][:tenant]

img_user = comp_admin_user
img_pass = comp_admin_pass
img_tenant = comp_admin_tenant

alt_comp_user = "crowbar2"
alt_comp_pass = "crowbar2"
alt_comp_tenant = "admin"

keystone_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "admin").address if keystone_address.nil?
keystone_token = node[:keystone][:service][:token]
keystone_admin_port = node[:keystone][:api][:admin_port]

image_ref = `glance -H #{keystone_address} -p 9292 -I admin -K crowbar -T admin -N http://localhost:5000/v2.0 index|grep ami|awk '{print \$1}'`.strip() 

alt_image_ref = image_ref
flavor_ref = "1"
alt_flavor_ref = "2"

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

template "/etc/tempest/tempest.conf" do
  source "tempest.conf.erb"
  mode 0644
  variables(
           :comp_user => comp_user,
           :comp_pass => comp_pass,
           :comp_tenant => comp_tenant,
           :alt_comp_user => alt_comp_user,
           :alt_comp_pass => alt_comp_pass,
           :alt_comp_tenant => alt_comp_tenant,
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

