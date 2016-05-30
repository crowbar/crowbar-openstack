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

nova = get_instance("roles:nova-controller")
keystone_settings = KeystoneHelper.keystone_settings(nova, "nova")

alt_comp_user = keystone_settings["default_user"]
alt_comp_pass = keystone_settings["default_password"]
alt_comp_tenant = keystone_settings["default_tenant"]

# Will only be set if this cloud is actually running heat
heat_trusts_delegated_roles = nil

tempest_comp_user = node[:tempest][:tempest_user_username]
tempest_comp_pass = node[:tempest][:tempest_user_password]
tempest_comp_tenant = node[:tempest][:tempest_user_tenant]

tempest_adm_user = node[:tempest][:tempest_adm_username]
tempest_adm_pass = node[:tempest][:tempest_adm_password]

# manila (share)
tempest_manila_settings = node[:tempest][:manila]

register_auth_hash = { user: keystone_settings["admin_user"],
                       password: keystone_settings["admin_password"],
                       tenant: keystone_settings["admin_tenant"] }

keystone_register "tempest tempest wakeup keystone" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  action :wakeup
end.run_action(:wakeup)

keystone_register "create tenant #{tempest_comp_tenant} for tempest" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  tenant_name tempest_comp_tenant
  action :add_tenant
end.run_action(:add_tenant)

v2_auth_url = KeystoneHelper.versioned_service_URL(
    keystone_settings["protocol"], keystone_settings["internal_url_host"],
    keystone_settings["service_port"], "2.0")
keystonev2 = "keystone --insecure --os_username #{tempest_comp_user} --os_password #{tempest_comp_pass} --os_tenant_name #{tempest_comp_tenant} --os_auth_url #{v2_auth_url}"

`#{keystonev2} endpoint-get --service orchestration &> /dev/null`
use_heat = $?.success?

users = [
          {"name" => tempest_comp_user, "pass" => tempest_comp_pass, "role" => "Member"},
          {"name" => tempest_adm_user, "pass" => tempest_adm_pass, "role" => "admin" }
        ]

if use_heat
  heat_trusts_delegated_roles = node[:heat][:trusts_delegated_roles]
  heat_trusts_delegated_roles.each do |role|
    users.push("name" => tempest_comp_user, "pass" => tempest_comp_pass, "role" => role)
  end
end

users.each do |user|
  keystone_register "add #{user["name"]}:#{user["pass"]} user" do
    protocol keystone_settings["protocol"]
    insecure keystone_settings["insecure"]
    host keystone_settings["internal_url_host"]
    port keystone_settings["admin_port"]
    auth register_auth_hash
    user_name user["name"]
    user_password user["pass"]
    tenant_name tempest_comp_tenant
    action :nothing
  end.run_action(:add_user)

  keystone_register "add #{user["name"]}:#{tempest_comp_tenant} user #{user["role"]} role" do
    protocol keystone_settings["protocol"]
    insecure keystone_settings["insecure"]
    host keystone_settings["internal_url_host"]
    port keystone_settings["admin_port"]
    auth register_auth_hash
    user_name user["name"]
    role_name user["role"]
    tenant_name tempest_comp_tenant
    action :nothing
  end.run_action(:add_access)

  keystone_register "add default ec2 creds for #{user["name"]}:#{tempest_comp_tenant}" do
    protocol keystone_settings["protocol"]
    insecure keystone_settings["insecure"]
    host keystone_settings["internal_url_host"]
    port keystone_settings["admin_port"]
    auth register_auth_hash
    user_name user["name"]
    tenant_name tempest_comp_tenant
    action :nothing
  end.run_action(:add_ec2)
end

# Give admin user access to tempest tenant
keystone_register "add #{keystone_settings['admin_user']}:#{tempest_comp_tenant} user admin role" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  user_name keystone_settings["admin_user"]
  role_name "admin"
  tenant_name tempest_comp_tenant
  action :nothing
end.run_action(:add_access)

# Create directories that we need
["", "bin", "etc", "etc/certs", "etc/cirros"].each do |subdir|
  directory "#{node[:tempest][:tempest_path]}/#{subdir}" do
    action :create
  end
end

machine_id_file = node[:tempest][:tempest_path] + "/machine.id"
alt_machine_id_file = node[:tempest][:tempest_path] + "/alt_machine.id"
docker_image_id_file = node[:tempest][:tempest_path] + "/docker_machine.id"

glance_node = search(:node, "roles:glance-server").first
insecure = "--insecure"

cirros_version = File.basename(node[:tempest][:tempest_test_image]).gsub(/^cirros-/, "").gsub(/-.*/, "")

bash "upload tempest test image" do
  code <<-EOH
IMAGE_URL=${IMAGE_URL:-"http://download.cirros-cloud.net/0.3.4/cirros-0.3.4-x86_64-uec.tar.gz"}

export OS_USERNAME=${OS_USERNAME:-admin}
export OS_TENANT_NAME=${OS_TENANT_NAME:-admin}
export OS_PASSWORD=${OS_PASSWORD:-admin}
export OS_AUTH_URL
export OS_IDENTITY_API_VERSION
export OS_USER_DOMAIN_NAME
export OS_PROJECT_DOMAIN_NAME

TEMP=$(mktemp -d)
IMG_DIR=$TEMP/image
IMG_FILE=$(basename $IMAGE_URL)
IMG_NAME="${IMG_FILE%-*}"

function extract_id() {
  grep ' id ' | awk '{ print $4 }'
}

function findfirst() {
  find $IMG_DIR -name "$1" | head -1
}

echo "Downloading image ... "
wget --no-verbose $IMAGE_URL --directory-prefix=$TEMP 2>&1 || exit $?

echo "Unpacking image ... "
mkdir $IMG_DIR
tar -xvzf $TEMP/$IMG_FILE -C $IMG_DIR || exit $?
rm -rf #{node[:tempest][:tempest_path]}/etc/cirros/*
cp -v $(findfirst '*-vmlinuz') $(findfirst '*-initrd') $(findfirst '*.img') #{node[:tempest][:tempest_path]}/etc/cirros/ || exit $?

echo -n "Adding kernel ... "
KERNEL_ID=$(glance #{insecure} --os-image-api-version 1 image-create \
    --name "$IMG_NAME-tempest-kernel" \
    --is-public True --container-format aki \
    --disk-format aki < $(findfirst '*-vmlinuz') | extract_id)
echo "done."
[ -n "$KERNEL_ID" ] || exit 1

echo -n "Adding ramdisk ... "
RAMDISK_ID=$(glance #{insecure} --os-image-api-version 1 image-create \
    --name="$IMG_NAME-tempest-ramdisk" \
    --is-public True --container-format ari \
    --disk-format ari < $(findfirst '*-initrd') | extract_id)
echo "done."
[ -n "$RAMDISK_ID" ] || exit 1

echo -n "Adding alt image ... "
ALT_MACHINE_ID=$(glance #{insecure} --os-image-api-version 1 image-create \
    --name="$IMG_NAME-tempest-machine-alt" \
    --is-public True --container-format ami --disk-format ami \
    --property kernel_id=$KERNEL_ID \
    --property ramdisk_id=$RAMDISK_ID < $(findfirst '*.img') | extract_id)
echo "done."
[ -n "$ALT_MACHINE_ID" ] || exit 1

echo -n "Saving alt machine id ..."
echo $ALT_MACHINE_ID > #{alt_machine_id_file}

echo -n "Adding image ... "
MACHINE_ID=$(glance #{insecure} --os-image-api-version 1 image-create \
    --name="$IMG_NAME-tempest-machine" \
    --is-public True --container-format ami --disk-format ami \
    --property kernel_id=$KERNEL_ID \
    --property ramdisk_id=$RAMDISK_ID < $(findfirst '*.img') | extract_id)
echo "done."
[ -n "$MACHINE_ID" ] || exit 1

echo -n "Saving machine id ..."
echo $MACHINE_ID > #{machine_id_file}
echo "done."

rm -rf $TEMP

glance #{insecure} image-list
EOH
  environment ({
    "IMAGE_URL" => node[:tempest][:tempest_test_image],
    "OS_USERNAME" => tempest_adm_user,
    "OS_PASSWORD" => tempest_adm_pass,
    "OS_TENANT_NAME" => tempest_comp_tenant,
    "OS_AUTH_URL" => keystone_settings["internal_auth_url"],
    "OS_IDENTITY_API_VERSION" => keystone_settings["api_version"],
    "OS_USER_DOMAIN_NAME" => keystone_settings["api_version"] != "2.0" ? "Default" : "",
    "OS_PROJECT_DOMAIN_NAME" => keystone_settings["api_version"] != "2.0" ? "Default" : ""
  })
  not_if { File.exist?(machine_id_file) }
end

flavor_ref = "6"
alt_flavor_ref = "7"
heat_flavor_ref = "8"

bash "create_yet_another_tiny_flavor" do
  code <<-EOH
  nova flavor-show tempest-stuff &> /dev/null || nova flavor-create tempest-stuff #{flavor_ref} 128 0 1 || exit 0
  nova flavor-show tempest-stuff-2 &> /dev/null || nova flavor-create tempest-stuff-2 #{alt_flavor_ref} 196 0 1 || exit 0
  nova flavor-show tempest-heat &> /dev/null || nova flavor-create tempest-heat #{heat_flavor_ref} 512 0 1 || exit 0
EOH
  environment ({
    "OS_USERNAME" => tempest_adm_user,
    "OS_PASSWORD" => tempest_adm_pass,
    "OS_TENANT_NAME" => tempest_comp_tenant,
    "NOVACLIENT_INSECURE" => "true",
    "OS_AUTH_URL" => keystone_settings["internal_auth_url"],
    "OS_IDENTITY_API_VERSION" => keystone_settings["api_version"],
    "OS_USER_DOMAIN_NAME" => keystone_settings["api_version"] != "2.0" ? "Default" : "",
    "OS_PROJECT_DOMAIN_NAME" => keystone_settings["api_version"] != "2.0" ? "Default" : ""
  })
end

ec2_access = `#{keystonev2} ec2-credentials-list | grep -v -- '\\-\\{5\\}' | tail -n 1 | tr -d '|' | awk '{print $2}'`.strip
ec2_secret = `#{keystonev2} ec2-credentials-list | grep -v -- '\\-\\{5\\}' | tail -n 1 | tr -d '|' | awk '{print $3}'`.strip
raise("Cannot fetch EC2 credentials ") if ec2_access.empty? || ec2_secret.empty?

`#{keystonev2} endpoint-get --service metering &> /dev/null`
use_ceilometer = $?.success?
`#{keystonev2} endpoint-get --service database &> /dev/null`
use_trove = $?.success?
`#{keystonev2} endpoint-get --service share &> /dev/null`
use_manila = $?.success?

# FIXME: should avoid search with no environment in query
neutrons = search(:node, "roles:neutron-server") || []
# FIXME: this should be 'all' instead
#
neutron_api_extensions = "provider,security-group,dhcp_agent_scheduler,external-net,ext-gw-mode,binding,agent,quotas,l3_agent_scheduler,multi-provider,router,extra_dhcp_opt,allowed-address-pairs,extraroute,metering,fwaas,service-type"

unless neutrons[0].nil?
  if neutrons[0][:neutron][:use_lbaas] then
    neutron_api_extensions += ",lbaas,lbaas_agent_scheduler"
  end
end

public_network_id = `neutron --insecure --os-user-domain-name Default --os-project-domain-name Default --os-username #{tempest_comp_user} --os-password #{tempest_comp_pass} --os-tenant-name #{tempest_comp_tenant} --os-auth-url #{keystone_settings["internal_auth_url"]} net-list -f csv -c id -- --name floating | tail -n 1 | cut -d'"' -f2`.strip
raise("Cannot fetch ID of floating network") if public_network_id.empty?

# FIXME: the command above should be good enough, but radosgw is broken with
# tempest; also should avoid search with no environment in query
#`#{keystone} endpoint-get --service object-store &> /dev/null`
#use_swift = $?.success?
swifts = search(:node, "roles:swift-proxy") || []
use_swift = !swifts.empty?
if use_swift
  swift_allow_versions = swifts[0][:swift][:allow_versions]
  swift_proposal_name = swifts[0][:swift][:config][:environment].gsub(/^swift-config-/, "")
  swift_cluster_name = "#{node[:domain]}_#{swift_proposal_name}"
else
  swift_allow_versions = false
  swift_cluster_name = nil
end

# FIXME: should avoid search with no environment in query
cinders = search(:node, "roles:cinder-controller") || []
storage_protocol = "iSCSI"
vendor_name = "Open Source"
cinders[0][:cinder][:volumes].each do |volume|
  if volume[:backend_driver] == "rbd"
    storage_protocol = "ceph"
    break
  elsif volume[:backend_driver] == "emc"
    vendor_name = "EMC"
    break
  elsif volume[:backend_driver] == "eqlx"
    vendor_name = "Dell"
    break
  elsif volume[:backend_driver] == "eternus"
    vendor_name = "FUJITSU"
    storage_protocol = "fibre_channel" if volume[:eternus][:protocol] == "fc"
    break
  elsif volume[:backend_driver] == "netapp"
    vendor_name = "NetApp"
    storage_protocol = "nfs" if volume[:netapp][:storage_protocol] == "nfs"
    break
  elsif volume[:backend_driver] == "vmware"
    vendor_name = "VMware"
    storage_protocol = "LSI Logic SCSI"
    break
  end
end

cinder_multi_backend = false
cinder_backend1_name = nil
cinder_backend2_name = nil
backend_names = cinders[0][:cinder][:volumes].map{ |volume| volume[:backend_name] }.uniq
if backend_names.length > 1
  cinder_multi_backend = true
  cinder_backend1_name = backend_names[0]
  cinder_backend2_name = backend_names[1]
end

kvm_compute_nodes = search(:node, "roles:nova-compute-kvm") || []
xen_compute_nodes = search(:node, "roles:nova-compute-xen") || []
docker_compute_nodes = search(:node, "roles:nova-compute-docker") || []

use_resize = kvm_compute_nodes.length > 1
use_livemigration = nova[:nova][:use_migration] && kvm_compute_nodes.length > 1

# create a flag to disable some test for xen (lp#1443898)
xen_only = !xen_compute_nodes.empty? && kvm_compute_nodes.empty?
file "#{node[:tempest][:tempest_path]}/flag-xen_only" do
  action xen_only ? :create : :delete
end

# tempest timeouts for ssh and connection can be different for XEN, a
# `nil` value will use the tempest default value
validation_connect_timeout = nil
validation_ssh_timeout = nil
if xen_only
  # Default: 60
  validation_connect_timeout = 90
  # Default: 300
  validation_ssh_timeout = 450
end

if !docker_compute_nodes.empty? && kvm_compute_nodes.empty?
  image_name = "cirros"

  bash "load docker image" do
    code <<-EOH

TEMP=$(mktemp -d)
IMG_FILE=$(basename $IMAGE_URL)

echo "Downloading image ... "
wget --no-verbose $IMAGE_URL --directory-prefix=$TEMP 2>&1 || exit $?

echo "Registering in glance ..."
DOCKER_IMAGE_ID=$(glance #{insecure} --os-image-api-version 1 image-create \
    --name #{image_name} \
    --container-format docker \
    --property hypervisor_type=docker \
    --disk-format raw \
    --is-public True  \
    --file $TEMP/$IMG_FILE \
    | grep ' id ' | awk '{ print $4 }')

[ -n "$DOCKER_IMAGE_ID" ] && echo "$DOCKER_IMAGE_ID" > #{docker_image_id_file}
rm -fr $TEMP

echo "Checking that deployment status ..."
[ -f #{docker_image_id_file} ] || exit 127

EOH
    environment ({
      "OS_USERNAME" => tempest_adm_user,
      "OS_PASSWORD" => tempest_adm_pass,
      "OS_TENANT_NAME" => tempest_comp_tenant,
      "OS_AUTH_URL" => keystone_settings["internal_auth_url"],
      "OS_IDENTITY_API_VERSION" => keystone_settings["api_version"],
      "OS_USER_DOMAIN_NAME" => keystone_settings["api_version"] != "2.0" ? "Default" : "",
      "OS_PROJECT_DOMAIN_NAME" => keystone_settings["api_version"] != "2.0" ? "Default" : "",
      "IMAGE_URL" => node[:tempest][:tempest_test_docker_image],
      "IMAGE_NAME" => image_name
    })
    not_if { File.exist?(docker_image_id_file) }
  end

  use_docker = true
  use_interface_attach = false
  use_rescue = false
  use_suspend = false
  # no vnc support: https://bugs.launchpad.net/nova-docker/+bug/1321818
  use_vnc = false
  # uptime inside docker in the same that in the host
  use_run_validation = false
  # blkid inside docker does not return attached devices
  use_config_drive = false
  image_regex = "^#{image_name}$"
else
  use_docker = false
  use_interface_attach = true
  use_rescue = true
  use_suspend = true
  use_vnc = true
  use_run_validation = true
  use_config_drive = true
  image_regex = "^cirros-#{cirros_version}-x86_64-tempest-machine$"
end

# FIXME: should avoid search with no environment in query
horizons = search(:node, "roles:horizon-server") || []
if horizons.empty?
  use_horizon = false
  horizon_host = "localhost"
  horizon_protocol = "http"
else
  horizon = horizons[0]
  use_horizon = true
  horizon_host = CrowbarHelper.get_host_for_admin_url(horizon, horizon[:horizon][:ha][:enabled])
  horizon_protocol = horizon[:horizon][:apache][:ssl] ? "https" : "http"
end

template "/etc/tempest/tempest.conf" do
  source "tempest.conf.erb"
  mode 0644
  variables(
    # general settings
    keystone_settings: keystone_settings,
    machine_id_file: use_docker ? docker_image_id_file : machine_id_file,
    alt_machine_id_file: alt_machine_id_file,
    tempest_path: node[:tempest][:tempest_path],
    use_swift: use_swift,
    use_horizon: use_horizon,
    use_heat: use_heat,
    use_ceilometer: use_ceilometer,
    use_trove: use_trove,
    use_manila: use_manila,
    # boto settings
    ec2_protocol: nova[:nova][:ssl][:enabled] ? "https" : "http",
    ec2_host: CrowbarHelper.get_host_for_admin_url(nova, nova[:nova][:ha][:enabled]),
    ec2_port: nova[:nova][:ports][:api_ec2],
    s3_host: CrowbarHelper.get_host_for_admin_url(nova, nova[:nova][:ha][:enabled]),
    s3_port: nova[:nova][:ports][:objectstore],
    ec2_access: ec2_access,
    ec2_secret: ec2_secret,
    # cli settings
    bin_path: "/usr/bin",
    # compute settings
    flavor_ref: flavor_ref,
    alt_flavor_ref: alt_flavor_ref,
    nova_api_v3: nova[:nova][:enable_v3_api],
    use_interface_attach: use_interface_attach,
    use_rescue: use_rescue,
    use_resize: use_resize,
    use_suspend: use_suspend,
    use_vnc: use_vnc,
    use_livemigration: use_livemigration,
    # compute-feature-enabled settings
    use_config_drive: use_config_drive,
    # dashboard settings
    horizon_host: horizon_host,
    horizon_protocol: horizon_protocol,
    # identity settings
    # FIXME: it's a bit unclear, but looking at the tempest code, we should set
    # this if any of the services is insecure, not just keystone
    ssl_insecure: keystone_settings["insecure"],
    comp_user: tempest_comp_user,
    comp_tenant: tempest_comp_tenant,
    comp_pass: tempest_comp_pass,
    alt_comp_user: alt_comp_user,
    alt_comp_tenant: alt_comp_tenant,
    alt_comp_pass: alt_comp_pass,
    # image settings
    http_image: node[:tempest][:tempest_test_image],
    # network settings
    public_network_id: public_network_id,
    neutron_api_extensions: neutron_api_extensions,
    # object storage settings
    swift_cluster_name: swift_cluster_name,
    object_versioning: swift_allow_versions,
    # orchestration settings
    heat_flavor_ref: heat_flavor_ref,
    # FIXME: until https://bugs.launchpad.net/tempest/+bug/1559078 only the
    # first element of this list will be used in the template (this works fine
    # for all of our default settings for stack_delegated_roles (single values)
    # but breaks in the (unlikely) case of anybody configuring multiple roles).
    heat_trusts_delegated_roles: heat_trusts_delegated_roles,
    # scenario settings
    cirros_version: cirros_version,
    image_regex: image_regex,
    # validation settings
    use_run_validation: use_run_validation,
    validation_connect_timeout: validation_connect_timeout,
    validation_ssh_timeout: validation_ssh_timeout,
    # volume settings
    cinder_multi_backend: cinder_multi_backend,
    cinder_backend1_name: cinder_backend1_name,
    cinder_backend2_name: cinder_backend2_name,
    storage_protocol: storage_protocol,
    vendor_name: vendor_name,
    use_docker: use_docker,
    # manila (share) settings
    manila_settings: tempest_manila_settings
  )
end

template "#{node[:tempest][:tempest_path]}/bin/tempest_smoketest.sh" do
  mode 0755
  source "tempest_smoketest.sh.erb"
  variables(
    comp_pass: tempest_comp_pass,
    comp_tenant: tempest_comp_tenant,
    comp_user: tempest_comp_user,
    keystone_settings: keystone_settings,
    tempest_path: node[:tempest][:tempest_path]
  )
end
