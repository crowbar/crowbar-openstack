#
# Copyright 2012 Dell, Inc.
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
# Cookbook Name:: cinder
# Recipe:: volume
#

include_recipe "#{@cookbook_name}::common"

def volume_exists(volname)
  Kernel.system("vgs #{volname}")
end

def make_loopback_file(volume)
  fname = volume[:local][:file_name]
  fsize = volume[:local][:file_size] * 1024 * 1024 * 1024 # Convert from GB to Bytes

  return if File.exists?(fname)

  fdir = ::File.dirname(fname)
  # this code will be executed at compile-time so we have to use ruby block
  # or get fs capacity from parent directory because at compile-time we have
  # no package resources done
  # creating enclosing directory and user/group here bypassing packages looks like
  # a bad idea. I'm not sure about postinstall behavior of cinder package.
  # Cap size at 90% of free space
  encl_dir=fdir
  while not File.directory?(encl_dir)
    encl_dir=encl_dir.sub(/\/[^\/]*$/,"")
  end
  max_fsize = ((`df -Pk #{encl_dir}`.split("\n")[1].split(" ")[3].to_i * 1024) * 0.90).to_i rescue 0
  fsize = max_fsize if fsize > max_fsize

  bash "Create local volume file #{fname}" do
    code "truncate -s #{fsize} #{fname}"
    not_if do
      File.exists?(fname)
    end
  end
end

def setup_loopback_device(volume)
  fname = volume[:local][:file_name]

  unless File.exists?(fname)
    Chef::Log.info("Loopback file #{fname} doesn't exist")
    return
  end

  sleep 1
  cmd = ["losetup", "-j", fname]
  check_loopback_device = Mixlib::ShellOut.new(cmd)
  if check_loopback_device.run_command.stdout.empty?
    Chef::Log.info("Attach #{fname} file to loop device")
    cmd = ["losetup", "-f", fname]
    attach_loopback_device = Mixlib::ShellOut.new(cmd)
    attach_loopback_device.run_command
  end
end

def make_loopback_volume(backend_id, volume)
  volname = volume[:local][:volume_name]
  fname = volume[:local][:file_name]

  return if volume_exists(volname)

  bash "Create volume group #{volname}" do
    code "vgcreate #{volname} `losetup -j #{fname} | cut -f1 -d:`"
    not_if "vgs #{volname}"
  end
end

def make_volume(node, backend_id, volume)
  volname = volume[:raw][:volume_name]
  cinder_raw_method = volume[:raw][:cinder_raw_method]

  return if volume_exists(volname)

  unclaimed_disks = BarclampLibrary::Barclamp::Inventory::Disk.unclaimed(node)
  claimed_disks = BarclampLibrary::Barclamp::Inventory::Disk.claimed(node, "Cinder")

  Chef::Log.info("Cinder: Using raw disks for volume backing (#{backend_id})")

  if unclaimed_disks.empty? && claimed_disks.empty?
    Chef::Log.fatal("There are no suitable disks for cinder")
    raise "There are no suitable disks for cinder"
  end

  if claimed_disks.empty?
    claimed_disks = if cinder_raw_method == "first"
                      [unclaimed_disks.first]
                    else
                      unclaimed_disks
                    end.select do |d|
      if d.claim("Cinder")
        Chef::Log.info("Cinder: Claimed #{d.name}")
        true
      else
        Chef::Log.info("Cinder: Ignoring #{d.name}")
        false
      end
    end
  end

  claimed_disks.each do |disk|
    bash "Create physical volume on #{disk.name}" do
      code <<-EOH
      dd if=/dev/zero of=#{disk.name} bs=1024 count=10
      blockdev --rereadpt  #{disk.name}
      pvcreate -f #{disk.name}
      EOH
      not_if "pvs #{disk.name}"
    end
  end

  # Make our volume group.
  bash "Create volume group #{volname}" do
    code "vgcreate #{volname} #{claimed_disks.map{ |d|d.name }.join(' ')}"
    not_if "vgs #{volname}"
  end
end

### Loop 1 over volumes
# this is required because of the boot.looplvm that need to be created before
# we create the LVM volume groups
loop_lvm_paths = []

node[:cinder][:volumes].each do |volume|
  if volume[:backend_driver] == "local"
    make_loopback_file(volume)
    if node[:platform] != "suse" || node[:platform_version].to_f >= 12.0
      setup_loopback_device(volume)
    end
    loop_lvm_paths << volume[:local][:file_name]
  end
end

# for older SLES
if node[:platform] == "suse" && node[:platform_version].to_f < 12.0
  # We need to create boot.looplvm before we create the volume groups; note
  # that the loopback files need to exist before we can use this script
  unless loop_lvm_paths.empty?
    template "boot.looplvm" do
      path "/etc/init.d/boot.looplvm"
      source "boot.looplvm.erb"
      owner "root"
      group "root"
      mode 0755
      variables(loop_lvm_paths: loop_lvm_paths.map{ |x| Shellwords.shellescape(x) }.join(" "))
    end

    service "boot.looplvm" do
      supports start: true, stop: true
      action [:enable]
      # We cannot use reload/restart, since status doesn't return 0 (which is expected since it's not running)
      subscribes :start, "template[boot.looplvm]", :immediately
    end
  end
end

### Loop 2 over volumes
# now do everything else we need to do
rbd_enabled = false

node[:cinder][:volumes].each_with_index do |volume, volid|
  backend_id = "backend-#{volume['backend_driver']}-#{volid}"

  case
    when volume[:backend_driver] == "emc"
      template "/etc/cinder/cinder_emc_config-#{backend_id}.xml" do
        source "cinder_emc_config.xml.erb"
        owner "root"
        group node[:cinder][:group]
        mode 0640
        variables(
          emc_params: volume["emc"]
        )
        notifies :restart, "service[cinder-volume]"
      end

    when volume[:backend_driver] == "eqlx"

    when volume[:backend_driver] == "local"
      make_loopback_volume(backend_id, volume)

    when volume[:backend_driver] == "raw"
      make_volume(node, backend_id, volume)

    when volume[:backend_driver] == "netapp"
      file "/etc/cinder/nfs_shares-#{backend_id}" do
        content volume[:netapp][:nfs_shares]
        owner "root"
        group node[:cinder][:group]
        mode "0640"
        action :create
        notifies :restart, "service[cinder-volume]"
        only_if { volume[:netapp][:storage_protocol] == "nfs" }
      end

    when volume[:backend_driver] == "eternus"
      template "/etc/cinder/cinder_eternus_dx_config-#{backend_id}.xml" do
        source "cinder_eternus_dx_config.xml.erb"
        owner "root"
        group node[:cinder][:group]
        mode 0640
        variables(
          eternus_params: volume["eternus"]
        )
        notifies :restart, "service[cinder-volume]"
      end

    when volume[:backend_driver] == "manual"

    when volume[:backend_driver] == "rbd"
      rbd_enabled = true

    when volume[:backend_driver] == "vmware"

  end
end

if rbd_enabled
  include_recipe "cinder::ceph"
end

if %w(rhel).include? node[:platform_family]
  package "scsi-target-utils"
else
  package "tgt"
end
# Note: Ubuntu provides cinder_tgt.conf with the package
if %w(rhel suse).include? node[:platform_family]
  cookbook_file "/etc/tgt/targets.conf" do
    source "cinder-volume.conf"
    notifies :restart, "service[tgt]"
  end
end

# for older SLES
if node[:platform] == "suse" && node[:platform_version].to_f < 12.0
  service "boot.lvm" do
    action [:enable]
  end
end

service "tgt" do
  supports status: true, restart: true, reload: true
  action [:enable, :start]
  service_name "tgtd" if %w(rhel suse).include? node[:platform_family]
  # Restart doesn't work correct for this service.
  if %w(rhel suse).include? node[:platform_family]
    restart_command "service tgtd stop; service tgtd start"
  else
    restart_command "stop tgt; start tgt"
  end
end

cinder_service("volume")
