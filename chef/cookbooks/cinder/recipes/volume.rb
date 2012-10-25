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

volname = node[:cinder][:volume][:volume_name]

checked_disks = []

node[:crowbar][:disks].each do |disk, data|
  checked_disks << disk if File.exists?("/dev/#{disk}") and data["usage"] == "Storage"
end

if checked_disks.empty? or node[:cinder][:volume][:volume_type] == "local"
  # only OS disk is exists, will use file storage
  fname = node["cinder"]["volume"]["local_file"]
  fdir = ::File.dirname(fname)
  fsize = node["cinder"]["volume"]["local_size"] * 1024 * 1024 * 1024 # Convert from GB to Bytes

  # Cap size at 90% of free space
  max_fsize = ((`df -Pk #{fdir}`.split("\n")[1].split(" ")[3].to_i * 1024) * 0.90).to_i rescue 0
  fsize = max_fsize if fsize > max_fsize

  bash "create local volume file" do
    code "truncate -s #{fsize} #{fname}"
    not_if do
      File.exists?(fname)
    end
  end

  bash "setup loop device for volume" do
    code "losetup -f --show #{fname}"
    not_if "losetup -j #{fname} | grep #{fname}"
  end

  bash "create volume group" do
    code "vgcreate #{volname} `losetup -j #{fname} | cut -f1 -d:`"
    not_if "vgs #{volname}"
  end

elsif node[:cinder][:volume][:volume_type] == "eqlx"
  # do nothing on the host
else
  raw_mode = node[:cinder][:volume][:cinder_raw_method]
  raw_list = node[:cinder][:volume][:cinder_volume_disks]
  # if all, then just use the checked_list
  raw_list = checked_disks if raw_mode == "all"

  if raw_list.empty? or raw_mode == "first"
    # use first non-OS disk for vg
    dname = "/dev/#{checked_disks.first}"
    bash "wipe partitions" do
      code "dd if=/dev/zero of=#{dname} bs=1024 count=1"
      not_if "vgs #{volname}"
    end
  else
    # use this disk list
    disk_list = []
    raw_list.each do |disk|
      disk_list << "/dev/#{disk}" if checked_disks.include?(disk)
      bash "wipe partitions #{disk}" do
        code "dd if=/dev/zero of=#{disk} bs=1024 count=1"
        not_if "vgs #{volname}"
      end
    end
    raise "Can't access any disk from the given list" if disk_list.empty?
    dname = disk_list.join(' ')
  end

  bash "create physical volume" do
    code "pvcreate #{dname}"
    not_if "pvs #{dname}"
  end

  bash "create volume group" do
    code "vgcreate #{volname} #{dname}"
    not_if "vgs #{volname}"
  end

end

#
# Put EQLX driver
# It's kinda hacky
#
if node[:cinder][:volume][:volume_type] == "eqlx"
  package("python-paramiko")
  #TODO(agordeev): use path_spec not hardcode
  cookbook_file "/opt/cinder/cinder/volume/eqlx.py" do
    mode "0755"
    source "eqlx.py"
  end
end

package "tgt"
cookbook_file "/etc/tgt/conf.d/cinder-volume.conf" do
  source "cinder-volume.conf"
end

cinder_service("volume")

# Restart doesn't work correct for this service.
bash "restart-tgt_#{@cookbook_name}" do
  code <<-EOH
    stop tgt
    start tgt
EOH
  action :nothing
end

service "tgt" do
  supports :status => true, :restart => true, :reload => true
  action :enable
  notifies :run, "bash[restart-tgt_#{@cookbook_name}]"
end
