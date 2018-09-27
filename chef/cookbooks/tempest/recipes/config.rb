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

# magnum (container)
tempest_magnum_settings = node[:tempest][:magnum]

# heat (orchestration)
tempest_heat_settings = node[:tempest][:heat]

register_auth_hash = { user: keystone_settings["admin_user"],
                       password: keystone_settings["admin_password"],
                       project: keystone_settings["admin_project"] }

keystone_register "tempest tempest wakeup keystone" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  action :wakeup
end

keystone_register "create tenant #{tempest_comp_tenant} for tempest" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  project_name tempest_comp_tenant
  action :add_project
end

auth_url = KeystoneHelper.service_URL(
    keystone_settings["protocol"], keystone_settings["internal_url_host"],
    keystone_settings["service_port"])
# for non-admin usage
comp_environment = "OS_USERNAME='#{tempest_comp_user}' "
comp_environment << "OS_PASSWORD='#{tempest_comp_pass}' "
comp_environment << "OS_PROJECT_NAME='#{tempest_comp_tenant}' "
comp_environment << "OS_AUTH_URL='#{auth_url}' "
comp_environment << "OS_IDENTITY_API_VERSION='#{keystone_settings["api_version"]}'"
openstackcli = "#{comp_environment} openstack --insecure"

# for admin usage (listing the available services)
adm_environment = "OS_USERNAME='#{tempest_adm_user}' "
adm_environment << "OS_PASSWORD='#{tempest_adm_pass}' "
adm_environment << "OS_PROJECT_NAME='#{tempest_comp_tenant}' "
adm_environment << "OS_AUTH_URL='#{auth_url}' "
adm_environment << "OS_IDENTITY_API_VERSION='#{keystone_settings["api_version"]}'"
openstackcli_adm = "#{adm_environment} openstack --insecure"

enabled_services = `#{openstackcli_adm} service list -f value -c Type`.split

users = [
          {"name" => tempest_comp_user, "pass" => tempest_comp_pass, "role" => "member"},
          {"name" => tempest_adm_user, "pass" => tempest_adm_pass, "role" => "admin" }
        ]

roles = [ 'anotherrole' ]

if enabled_services.include?("metering")
  rabbitmq_settings = fetch_rabbitmq_settings

  unless rabbitmq_settings[:enable_notifications]
    # without rabbitmq notification clients configured the ceilometer
    # tempest tests will fail so skip them
    enabled_services = enabled_services - ["metering"]
  end
end

heat_server = search(:node, "roles:heat-server").first
if enabled_services.include?("orchestration") && !heat_server.nil?
  heat_trusts_delegated_roles = heat_server[:heat][:trusts_delegated_roles]
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
    project_name tempest_comp_tenant
    action :add_user
  end

roles.each do |role|
  keystone_register "tempest create role #{role}" do
    protocol keystone_settings["protocol"]
    insecure keystone_settings["insecure"]
    host keystone_settings["internal_url_host"]
    port keystone_settings["admin_port"]
    auth register_auth_hash
    role_name role
    action :add_role
  end
end

  keystone_register "add #{user["name"]}:#{tempest_comp_tenant} user #{user["role"]} role" do
    protocol keystone_settings["protocol"]
    insecure keystone_settings["insecure"]
    host keystone_settings["internal_url_host"]
    port keystone_settings["admin_port"]
    auth register_auth_hash
    user_name user["name"]
    role_name user["role"]
    project_name tempest_comp_tenant
    action :add_access
  end

  keystone_register "add default ec2 creds for #{user["name"]}:#{tempest_comp_tenant}" do
    protocol keystone_settings["protocol"]
    insecure keystone_settings["insecure"]
    host keystone_settings["internal_url_host"]
    port keystone_settings["admin_port"]
    auth register_auth_hash
    user_name user["name"]
    project_name tempest_comp_tenant
    action :add_ec2
  end
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
  project_name tempest_comp_tenant
  action :add_access
end

# Create directories that we need
["", "bin", "etc", "etc/certs", "etc/cirros"].each do |subdir|
  directory "#{node[:tempest][:tempest_path]}/#{subdir}" do
    action :create
  end
end

machine_id_file = node[:tempest][:tempest_path] + "/machine.id"
alt_machine_id_file = node[:tempest][:tempest_path] + "/alt_machine.id"

insecure = "--insecure"

tempest_test_image = node[:tempest][:tempest_test_images][node[:kernel][:machine]]

cirros_version = File.basename(tempest_test_image).split("-")[1]
cirros_arch = File.basename(tempest_test_image).split("-")[2]

bash "upload tempest test image" do
  code <<-EOH
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
KERNEL_ID=$(glance #{insecure} image-create \
    --name "$IMG_NAME-tempest-kernel" \
    --visibility public --container-format aki \
    --disk-format aki < $(findfirst '*-vmlinuz') | extract_id)
echo "done."
[ -n "$KERNEL_ID" ] || exit 1

echo -n "Adding ramdisk ... "
RAMDISK_ID=$(glance #{insecure} image-create \
    --name="$IMG_NAME-tempest-ramdisk" \
    --visibility public --container-format ari \
    --disk-format ari < $(findfirst '*-initrd') | extract_id)
echo "done."
[ -n "$RAMDISK_ID" ] || exit 1

echo -n "Adding alt image ... "
ALT_MACHINE_ID=$(glance #{insecure} image-create \
    --name="$IMG_NAME-tempest-machine-alt" \
    --visibility public --container-format ami --disk-format ami \
    --property kernel_id=$KERNEL_ID \
    --property ramdisk_id=$RAMDISK_ID < $(findfirst '*.img') | extract_id)
echo "done."
[ -n "$ALT_MACHINE_ID" ] || exit 1

echo -n "Saving alt machine id ..."
echo $ALT_MACHINE_ID > #{alt_machine_id_file}

echo -n "Adding image ... "
MACHINE_ID=$(glance #{insecure} image-create \
    --name="$IMG_NAME-tempest-machine" \
    --visibility public --container-format ami --disk-format ami \
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
    "IMAGE_URL" => tempest_test_image,
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

ruby_block "fetch ec2 credentials" do
  block do
    ec2_access = `#{openstackcli} ec2 credentials list -f value -c Access`.strip
    ec2_secret = `#{openstackcli} ec2 credentials list -f value -c Secret`.strip
    raise("Cannot fetch EC2 credentials ") if ec2_access.empty? || ec2_secret.empty?
    node[:tempest][:ec2_access] = ec2_access
    node[:tempest][:ec2_secret] = ec2_secret
  end
end

# FIXME: should avoid search with no environment in query
neutrons = search(:node, "roles:neutron-server") || []
# FIXME: this should be 'all' instead
#
#
neutron_api_extensions = [
  "address-scope",
  "agent",
  "allowed-address-pairs",
  "auto-allocated-topology",
  "binding",
  "default-subnetpools",
  "dhcp_agent_scheduler",
  "external-net",
  "ext-gw-mode",
  "extra_dhcp_opt",
  "extraroute",
  "flavors",
  "fwaas",
  "fwaasrouterinsertion",
  "hm_max_retries_down",
  "l3_agent_scheduler",
  "l3-flavors",
  "metering",
  "multi-provider",
  "net-mtu",
  "network_availability_zone",
  "network-ip-availability",
  "pagination",
  "port-security",
  "project-id",
  "provider",
  "quotas",
  "router",
  "router_availability_zone",
  "security-group",
  "service-type",
  "shared_pools",
  "sorting",
  "standard-attr-description",
  "standard-attr-revisions",
  "subnet_allocation",
  "subnet-service-types",
  "tag",
].join(",")

unless neutrons[0].nil?
  if neutrons[0][:neutron][:use_lbaas] then
    neutron_api_extensions += ",lbaasv2,lbaas_agent_schedulerv2,lb-graph,lb_network_vip"
  end
end

ruby_block "get public network id" do
  block do
    cmd = "#{openstackcli} --os-user-domain-name Default --os-project-domain-name Default"
    cmd << " network show -f value -c id floating"
    public_network_id =  `#{cmd}`.strip
    raise("Cannot fetch ID of floating network") if public_network_id.empty?
    node[:tempest][:public_network_id] = public_network_id
  end
end

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
cinder_snapshot = true
use_attach_encrypted_volume = true
cinders[0][:cinder][:volumes].each do |volume|
  if volume[:backend_driver] == "rbd"
    storage_protocol = "ceph"
    # no encryption support for rbd-backed volumes
    use_attach_encrypted_volume = false
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
  elsif volume[:backend_driver] == "nfs"
    storage_protocol = "nfs"
    cinder_snapshot = volume[:nfs][:nfs_snapshot]
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
  use_interface_attach = false
  use_rescue = false
  use_suspend = false
  use_vnc = node[:kernel][:machine] != "aarch64"
  use_run_validation = false
  use_config_drive = false
end

unless kvm_compute_nodes.empty?
  use_interface_attach = true
  use_rescue = true
  use_suspend = true
  use_vnc = node[:kernel][:machine] != "aarch64"
  use_run_validation = true
  use_config_drive = true
  image_regex = "^cirros-#{cirros_version}-#{cirros_arch}-tempest-machine$"
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
  mode 0o640
  variables(
    lazy {
      {
        # general settings
        keystone_settings: keystone_settings,
        machine_id_file: machine_id_file,
        alt_machine_id_file: alt_machine_id_file,
        tempest_path: node[:tempest][:tempest_path],
        use_swift: use_swift,
        use_horizon: use_horizon,
        enabled_services: enabled_services,
        # boto settings
        ec2_protocol: nova[:nova][:ssl][:enabled] ? "https" : "http",
        ec2_host: CrowbarHelper.get_host_for_admin_url(nova, nova[:nova][:ha][:enabled]),
        ec2_port: nova[:nova][:ports][:api_ec2],
        s3_host: CrowbarHelper.get_host_for_admin_url(nova, nova[:nova][:ha][:enabled]),
        s3_port: nova[:nova][:ports][:objectstore],
        ec2_access: node[:tempest][:ec2_access],
        ec2_secret: node[:tempest][:ec2_secret],
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
        use_attach_encrypted_volume: use_attach_encrypted_volume,
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
        http_image: tempest_test_image,
        # network settings
        public_network_id: node[:tempest][:public_network_id],
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
        cirros_arch: cirros_arch,
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
        cinder_snapshot: cinder_snapshot,
        storage_protocol: storage_protocol,
        vendor_name: vendor_name,
        # manila (share) settings
        manila_settings: tempest_manila_settings,
        # magnum (container) settings
        magnum_settings: tempest_magnum_settings,
        # heat (orchestration) settings
        heat_settings: tempest_heat_settings
      }
    }
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
