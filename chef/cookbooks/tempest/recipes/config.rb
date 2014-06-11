#
# Cookbook Name:: tempest
# Recipe:: config
#
# Copyright 2011, Dell, Inc.
# Copyright 2012, Dell, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#


env_filter = " AND nova_config_environment:nova-config-#{node[:tempest][:nova_instance]}"

novas = search(:node, "roles:nova-multi-controller#{env_filter}") || []
if novas.length > 0
  nova = novas[0]
  nova = node if nova.name == node.name
else
  nova = node
end

env_filter = " AND keystone_config_environment:keystone-config-#{nova[:nova][:keystone_instance]}"

keystones = search(:node, "roles:keystone-server#{env_filter}") || []
if keystones.length > 0
  keystone = keystones[0]
  keystone = node if keystone.name == node.name
else
  keystone = node
end

keystone_port = keystone[:keystone][:api][:service_port]

alt_comp_user = keystone[:keystone][:default][:username]
alt_comp_pass = keystone[:keystone][:default][:password]
alt_comp_tenant = keystone[:keystone][:default][:tenant]

tempest_comp_user = node[:tempest][:tempest_user_username]
tempest_comp_pass = node[:tempest][:tempest_user_password]
tempest_comp_tenant = node[:tempest][:tempest_user_tenant]

tempest_adm_user = node[:tempest][:tempest_adm_username]
tempest_adm_pass = node[:tempest][:tempest_adm_password]

keystone_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(keystone, "admin").address if keystone_address.nil?
keystone_token = keystone[:keystone][:service][:token]
keystone_admin_port = keystone[:keystone][:api][:admin_port]

keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)

env_filter = " AND glance_config_environment:glance-config-#{nova[:nova][:glance_instance]}"

glances = search(:node, "roles:glance-server#{env_filter}") || []
if glances.length > 0
  glance = glances[0]
  glance = node if glance.name == node.name
else
  glance = node
end

glance_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(glance, "admin").address if glance_address.nil?
glance_port = glance[:glance][:api][:bind_port]

keystone_register "tempest tempest wakeup keystone" do
  protocol keystone_settings['protocol']
  host keystone_settings['internal_url_host']
  port keystone_settings['admin_port']
  token keystone_settings['admin_token']
  action :wakeup
end.run_action(:wakeup)

keystone_register "create tenant #{tempest_comp_tenant} for tempest" do
  protocol keystone_settings['protocol']
  host keystone_settings['internal_url_host']
  port keystone_settings['admin_port']
  token keystone_settings['admin_token']

  tenant_name tempest_comp_tenant
  action :add_tenant
end.run_action(:add_tenant)

users = [
          {'name' => tempest_comp_user, 'pass' => tempest_comp_pass, 'role' => 'Member'},
          {'name' => tempest_adm_user, 'pass' => tempest_adm_pass, 'role' => 'admin' },
        ]
users.each do |user|

  keystone_register "add #{user["name"]}:#{user["pass"]} user" do
    protocol keystone_settings['protocol']
    host keystone_settings['internal_url_host']
    port keystone_settings['admin_port']
    token keystone_settings['admin_token']
    user_name user["name"]
    user_password user["pass"]
    tenant_name tempest_comp_tenant
    action :nothing
  end.run_action(:add_user)

  keystone_register "add #{user["name"]}:#{tempest_comp_tenant} user #{user["role"]} role" do
    protocol keystone_settings['protocol']
    host keystone_settings['internal_url_host']
    port keystone_settings['admin_port']
    token keystone_settings['admin_token']
    user_name user["name"]
    role_name user["role"]
    tenant_name tempest_comp_tenant
    action :nothing
  end.run_action(:add_access)

  keystone_register "add default ec2 creds for #{user["name"]}:#{tempest_comp_tenant}" do
    protocol keystone_settings['protocol']
    host keystone_settings['internal_url_host']
    port keystone_settings['admin_port']
    auth ({
      :tenant => keystone_settings['admin_tenant'],
      :user => keystone_settings['admin_user'],
      :password => keystone_settings['admin_password']
    })
    user_name user["name"]
    tenant_name tempest_comp_tenant
    action :nothing
  end.run_action(:add_ec2)

end

# Give admin user access to tempest tenant
keystone_register "add #{keystone_settings['admin_user']}:#{tempest_comp_tenant} user admin role" do
  protocol keystone_settings['protocol']
  host keystone_settings['internal_url_host']
  port keystone_settings['admin_port']
  token keystone_settings['admin_token']
  user_name keystone_settings['admin_user']
  role_name "admin"
  tenant_name tempest_comp_tenant
  action :nothing
end.run_action(:add_access)

directory "#{node[:tempest][:tempest_path]}" do
  action :create
end

directory "#{node[:tempest][:tempest_path]}/bin" do
  action :create
end

directory "#{node[:tempest][:tempest_path]}/etc" do
  action :create
end

directory "#{node[:tempest][:tempest_path]}/etc/certs" do
  action :create
end

directory "#{node[:tempest][:tempest_path]}/etc/cirros" do
  action :create
end

machine_id_file = node[:tempest][:tempest_path] + '/machine.id'

venv_prefix_path = node[:tempest][:use_virtualenv] ? ". /opt/tempest/.venv/bin/activate && " : nil
bin_path = node[:tempest][:use_virtualenv] ? "/opt/tempest/.venv/bin" : "/usr/bin/"

bash "upload tempest test image" do
  code <<-EOH
IMAGE_URL=${IMAGE_URL:-"http://download.cirros-cloud.net/0.3.2/cirros-0.3.2-x86_64-uec.tar.gz"}

OS_USER=${OS_USER:-admin}
OS_TENANT=${OS_TENANT:-admin}
OS_PASSWORD=${OS_PASSWORD:-admin}

TEMP=$(mktemp -d)
IMG_DIR=$TEMP/image
IMG_FILE=$(basename $IMAGE_URL)
IMG_NAME="${IMG_FILE%-*}"

function glance_it() {
#{venv_prefix_path} glance -I $OS_USER -T $OS_TENANT -K $OS_PASSWORD -N http://$KEYSTONE_HOST:5000/v2.0 -H $GLANCE_HOST $@
}

function extract_id() {
cut -d ":" -f2 | tr -d " "
}

function findfirst() {
find $IMG_DIR -name "$1" | head -1
}

echo "Downloading image ... "
wget $IMAGE_URL --directory-prefix=$TEMP || exit $?

echo "Unpacking image ... "
mkdir $IMG_DIR
tar -xvzf $TEMP/$IMG_FILE -C $IMG_DIR || exit $?
rm -rf #{node[:tempest][:tempest_path]}/etc/cirros/*
cp -v $(findfirst '*-vmlinuz') $(findfirst '*-initrd') $(findfirst '*.img') #{node[:tempest][:tempest_path]}/etc/cirros/

echo -n "Adding kernel ... "
KERNEL_ID=$(glance_it add --silent-upload name="$IMG_NAME-tempest-kernel" is_public=true container_format=aki disk_format=aki < $(findfirst '*-vmlinuz') | extract_id)
echo "done."

echo -n "Adding ramdisk ... "
RAMDISK_ID=$(glance_it add --silent-upload name="$IMG_NAME-tempest-ramdisk" is_public=true container_format=ari disk_format=ari < $(findfirst '*-initrd') | extract_id)
echo "done."

echo -n "Adding image ... "
MACHINE_ID=$(glance_it add --silent-upload name="$IMG_NAME-tempest-machine" is_public=true container_format=ami disk_format=ami kernel_id=$KERNEL_ID ramdisk_id=$RAMDISK_ID < $(findfirst '*.img') | extract_id)
echo "done."

echo -n "Saving machine id ..."
echo $MACHINE_ID > #{machine_id_file}
echo "done."

glance_it index
EOH
  environment ({
    'IMAGE_URL' => node[:tempest][:tempest_test_image],
    'OS_USER' => tempest_comp_user,
    'OS_PASSWORD' => tempest_comp_pass,
    'OS_TENANT' => tempest_comp_tenant,
    'KEYSTONE_HOST' => keystone_address,
    'GLANCE_HOST' => glance_address
  })
  not_if { File.exists?(machine_id_file) }
end

flavor_ref = "6"
alt_flavor_ref = "7"

bash "create_yet_another_tiny_flavor" do
  code <<-EOH
  #{venv_prefix_path} nova --os_username #{tempest_adm_user} --os_password #{tempest_adm_pass} --os_tenant_name #{tempest_comp_tenant} --os_auth_url http://#{keystone_address}:5000/v2.0 flavor-create tempest-stuff #{flavor_ref} 128 0 1 || exit 0
  #{venv_prefix_path} nova --os_username #{tempest_adm_user} --os_password #{tempest_adm_pass} --os_tenant_name #{tempest_comp_tenant} --os_auth_url http://#{keystone_address}:5000/v2.0 flavor-create tempest-stuff-2 #{alt_flavor_ref} 196 0 1 || exit 0
EOH
end

ec2_access = `keystone --os_username #{tempest_comp_user} --os_password #{tempest_comp_pass} --os_tenant_name #{tempest_comp_tenant} --os_auth_url http://#{keystone_address}:5000/v2.0 ec2-credentials-list | grep -v -- '\\-\\{5\\}' | tail -n 1 | tr -d '|' | awk '{print $2}'`
ec2_secret = `keystone --os_username #{tempest_comp_user} --os_password #{tempest_comp_pass} --os_tenant_name #{tempest_comp_tenant} --os_auth_url http://#{keystone_address}:5000/v2.0 ec2-credentials-list | grep -v -- '\\-\\{5\\}' | tail -n 1 | tr -d '|' | awk '{print $3}'`
cirros_version = "0.3.2"

tempest_conf = "#{node[:tempest][:tempest_path]}/etc/tempest.conf"
if %w(suse redhat centos).include?(node.platform)
  tempest_conf = "/etc/tempest/tempest.conf"
end

swifts = search(:node, "roles:swift-proxy") || []
heats = search(:node, "roles:heat-server") || []
ceilometers = search(:node, "roles:ceilometer-server") || []
horizons = search(:node, "roles:nova_dashboard-server") || []

neutrons = search(:node, "roles:neutron-server") || []

public_network_id = `neutron --os_username #{tempest_comp_user} --os_password #{tempest_comp_pass} --os_tenant_name #{tempest_comp_tenant} --os_auth_url http://#{keystone_address}:5000/v2.0 net-list -f csv -c id -- --name floating | tail -n 1 | cut -d'"' -f2 `

template "#{tempest_conf}" do
  source "tempest.conf.erb"
  mode 0644
  variables(
    :alt_comp_pass => alt_comp_pass,
    :alt_comp_tenant => alt_comp_tenant,
    :alt_comp_user => alt_comp_user,
    :alt_flavor_ref => alt_flavor_ref,
    :bin_path => bin_path,
    :cirros_version => cirros_version,
    :comp_pass => tempest_comp_pass,
    :comp_tenant => tempest_comp_tenant,
    :comp_user => tempest_comp_user,
    :ec2_access => ec2_access,
    :ec2_secret => ec2_secret,
    :flavor_ref => flavor_ref,
    :img_host => glance_address,
    :img_port => glance_port,
    :key_host => keystone_address,
    :key_port => keystone_port,
    :keystone_settings => keystone_settings,
    :machine_id_file => machine_id_file,
    :nova_host => nova.name,
    :public_network_id => public_network_id,
    :tempest_path => node[:tempest][:tempest_path],
    :use_heat => !heats.empty?,
    :use_ceilometer => !ceilometers.empty?,
    :use_horizon => !horizons.empty?,
    :use_neutron => !neutrons.empty?,
    :use_swift => !swifts.empty?
  )
end

nosetests = "/opt/tempest/.venv/bin/nosetests"


["#{node[:tempest][:tempest_path]}/bin/tempest_smoketest.sh",
 "#{node[:tempest][:tempest_path]}/bin/tempest_cleanup.sh"].each do |p|

  template "#{p}" do
    mode 0755
    source "#{(p.rpartition '/')[2]}.erb"
    variables(
      :alt_comp_pass => alt_comp_pass,
      :alt_comp_tenant => alt_comp_tenant,
      :alt_comp_user => alt_comp_user,
      :comp_pass => tempest_comp_pass,
      :comp_tenant => tempest_comp_tenant,
      :comp_user => tempest_comp_user,
      :key_host => keystone_address,
      :key_port => keystone_port,
      :keystone_settings => keystone_settings,
      :nosetests => nosetests,
      :tempest_path => node[:tempest][:tempest_path]
    )
  end
end

cookbook_file "#{node[:tempest][:tempest_path]}/bin/run_tempest.py" do
  source "run_tempest.py"
end
