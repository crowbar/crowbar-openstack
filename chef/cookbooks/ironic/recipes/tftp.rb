# frozen_string_literal: true
# Copyright 2016, SUSE
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License
# You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied
# See the License for the specific language governing permissions and
# limitations under the License
#

ironic_ip = Barclamp::Inventory.get_network_by_type(node, "ironic").address

tftproot = node[:ironic][:tftproot]
map_file = "#{tftproot}/map-file"

case node[:platform_family]
when "debian"
  package "tftpd-hpa"
  bash "stop ubuntu tftpd" do
    code "service tftpd-hpa stop; killall in.tftpd; rm /etc/init/tftpd-hpa.conf"
    only_if "test -f /etc/init/tftpd-hpa.conf"
  end
  package "grub-efi-amd64-signed"
  package "shim-signed"
when "rhel"
  package "tftp-server"
  package "grub2-efi"
  package "shim"
when "suse"
  package "tftp"
  package "grub2-efi"
  package "shim"
end

directory tftproot do
  action :create
  owner "ironic"
  group "ironic"
  mode "0755"
  recursive true
end

package "syslinux"

["pxelinux.0", "chain.c32"].each do |f|
  ["share", "lib"].each do |d|
    next unless ::File.exist?("/usr/#{d}/syslinux/#{f}")
    bash "Install #{f}" do
      code "cp /usr/#{d}/syslinux/#{f} #{tftproot}"
      not_if "cmp /usr/#{d}/syslinux/#{f} #{tftproot}/#{f}"
    end
    break
  end
end

# TODO: adjust locations for other distros
bash "Install shim.efi" do
  code "cp /usr/lib64/efi/shim.efi #{tftproot}/bootx64.efi"
  not_if "cmp /usr/lib64/efi/shim.efi #{tftproot}/bootx64.efi"
end

bash "Install grub.efi" do
  code "cp /usr/lib/grub2/x86_64-efi/grub.efi #{tftproot}/grub.efi"
  not_if "cmp /usr/lib/grub2/x86_64-efi/grub.efi #{tftproot}/grub.efi"
end

template "#{tftproot}/grub.cfg" do
  source "grub.cfg.erb"
  owner "root"
  group "root"
  mode "0644"
  variables(tftproot: tftproot)
end

template map_file do
  source "map-file.erb"
  owner "root"
  group "root"
  mode "0644"
  variables(tftproot: tftproot)
end

if node[:platform_family] == "suse"
  template "/etc/systemd/system/tftp.service" do
    source "tftp.service.erb"
    owner "root"
    group "root"
    mode "0644"
    variables(tftproot: tftproot, ironic_ip: ironic_ip, map_file: map_file)
  end

  service "tftp.service" do
    if node[:provisioner][:enable_pxe]
      action ["enable", "start"]
      subscribes :restart, resources("template[#{map_file}]")
      subscribes :restart, resources("template[/etc/systemd/system/tftp.service]")
    else
      action ["disable", "stop"]
    end
  end
  # No need for utils_systemd_service_restart: it's handled in the template already

  bash "reload systemd after tftp.service update" do
    code "systemctl daemon-reload"
    action :nothing
    subscribes :run, resources(template: "/etc/systemd/system/tftp.service"), :immediately
  end
else
  # TODO: support other platforms
  include_recipe "bluepill"
end
