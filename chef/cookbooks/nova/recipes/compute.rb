#
# Cookbook Name:: nova
# Recipe:: compute
#
# Copyright 2010, Opscode, Inc.
# Copyright 2011, Dell, Inc.
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

include_recipe "nova::neutron"
include_recipe "nova::config"

if %w(rhel suse).include?(node[:platform_family])
  # Start open-iscsi daemon, since nova-compute is going to use it and stumble over the
  # "starting daemon" messages otherwise
  package "open-iscsi"
  service "open-iscsi" do
    supports status: true, start: true, stop: true, restart: true
    action [:enable, :start]
    if node[:platform_family] == "suse"
      service_name "iscsid"
    end
  end
  utils_systemd_service_restart "open-iscsi"
end

case node[:nova][:libvirt_type]
  when "ironic"
    package "python-ironicclient"

  when "zvm"
    package "openstack-nova-virt-zvm"

  when "kvm", "lxc", "qemu", "xen"
    if %w(rhel suse).include?(node[:platform_family])
      # make sure that the libvirt package is present before other actions try to access /etc/qemu.conf
      package "libvirt" do
        action :nothing
      end.run_action(:install)

      # install libosinfo to provide hardware properties when driver is libvirt
      package "typelib-1_0-Libosinfo-1_0"

      # Generate a UUID, as DMI's system uuid is unreliable
      if node[:nova][:host_uuid].nil?
        node.set[:nova][:host_uuid] = `uuidgen`.strip
        node.save
      end

      if node[:nova]["use_migration"]
        migration_network = node[:nova][:migration][:network]
        listen_addr = Barclamp::Inventory.get_network_by_type(node, migration_network).address
      else
        # still put a valid address
        listen_addr = Barclamp::Inventory.get_network_by_type(node, "admin").address
      end

      template "/etc/libvirt/libvirtd.conf" do
        source "libvirtd.conf.erb"
        group "root"
        owner "root"
        mode 0644
        variables(
          libvirtd_host_uuid: node[:nova][:host_uuid],
          libvirtd_listen_tcp: node[:nova]["use_migration"] ? 1 : 0,
          libvirtd_listen_addr: listen_addr,
          libvirtd_auth_tcp: node[:nova]["use_migration"] ? "none" : "sasl"
        )
        notifies :create, "ruby_block[restart_libvirtd]", :immediately
      end

      case node[:nova][:libvirt_type]
        when "kvm", "qemu"
          package "qemu"

          if node[:kernel][:machine] == "aarch64"
            package "qemu-arm"
            package "qemu-uefi-aarch64"
          end

          if node[:kernel][:machine] == "x86_64" &&
              node[:platform_family] == "suse" && node[:platform_version].to_f > 12.1
            package "qemu-ovmf-x86_64"
          end

          # Use a ruby block for consistency with the other call
          ruby_block "set boot kernel" do
            block do
              NovaBootKernel.set_boot_kernel_and_trigger_reboot(node)
            end
          end

          if node[:nova][:libvirt_type] == "kvm"
            package "qemu-kvm" if node[:kernel][:machine] == "x86_64"

            # only install on architectures that support Ceph
            if node[:kernel][:machine] =~ /aarch64|x86_64/
              package "qemu-block-rbd"
            end

            execute "enable kvm intel nested virt" do
              command <<-SHELL
                  grep -q nested /etc/modprobe.d/80-kvm-intel.conf ||
                    echo "options kvm_intel nested=1" > /etc/modprobe.d/80-kvm-intel.conf
                  ! grep -q N /sys/module/kvm_intel/parameters/nested ||
                    /sbin/modprobe -r kvm_intel
              SHELL
              only_if do
                node[:nova][:kvm][:nested_virt] &&
                  `uname -r`.include?("default") &&
                  system("grep -qw vmx /proc/cpuinfo")
              end
            end

            # load modules only when appropriate kernel is present
            execute "loading kvm modules" do
              command <<-EOF
                  grep -qw vmx /proc/cpuinfo && /sbin/modprobe kvm-intel
                  grep -qw svm /proc/cpuinfo && /sbin/modprobe kvm-amd
                  grep -q POWER /proc/cpuinfo && /sbin/modprobe kvm
                  /sbin/modprobe vhost-net
                  /sbin/modprobe nbd
              EOF
              only_if { `uname -r`.include?("default") }
            end
          end

        when "xen"
          %w{kernel-xen xen xen-tools}.each do |pkg|
            package pkg
          end
          # openSUSE and SLES12SP2 use the module shipped with upstream kernel
          if node[:network][:needs_openvswitch] &&
              node[:platform] == "suse" && node[:platform_version].to_f < 12.2
            package "openvswitch-kmp-xen"
          end

          service "xend" do
            action :nothing
            supports status: true, start: true, stop: true, restart: true
            # restart xend only when xen kernel is already present
            only_if { Dir.exist?("/proc/xen") }
          end

          template "/etc/xen/xend-config.sxp" do
            source "xend-config.sxp.erb"
            group "root"
            owner "root"
            mode 0644
            variables(
              node_platform_family: node[:platform_family],
              libvirt_migration: node[:nova]["use_migration"],
              shared_instances: node[:nova]["use_shared_instance_storage"],
              libvirtd_listen_tcp: node[:nova]["use_migration"] ? 1 : 0,
              libvirtd_listen_addr: Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "admin").address
            )
            notifies :restart, "service[xend]", :delayed
          end

          # Use a ruby block as we need the kernel to be installed when running this
          ruby_block "set boot kernel" do
            block do
              NovaBootKernel.set_boot_kernel_and_trigger_reboot(node, "xen")
            end
          end
        when "lxc"
          package "lxc"

          service "boot.cgroup" do
            action [:enable, :start]
          end
      end

      # change libvirt to run qemu as user qemu
      # make sure to only set qemu:kvm for kvm and qemu deployments, use
      # system defaults for xen
      if ["kvm", "qemu"].include?(node[:nova][:libvirt_type])
        libvirt_user = "qemu"
        libvirt_group = "kvm"
      else
        libvirt_user = "root"
        libvirt_group = "root"
      end

      template "/etc/libvirt/qemu.conf" do
        source "qemu.conf.erb"
        group "root"
        owner "root"
        mode 0644
        variables(
            user: libvirt_user,
            group: libvirt_group
        )
        notifies :create, "ruby_block[restart_libvirtd]", :immediately
      end

      # This block is here to allow to restart libvirtd as soon as possible
      # after configuration changes (notified from the qemu.conf and libvirtd.conf
      # templates above), while avoiding it to restart multiple times, like it would
      # when we'd sent an :immediate restart notification directly to the service.
      # We need a (somewhat) immediate restart of libvirtd to avoid race conditions
      # and ordering issues with the delayed restart of nova-compute
      # See: https://bugzilla.suse.com/show_bug.cgi?id=1016302
      ruby_block "restart_libvirtd" do
        block do
          r = resources(service: "libvirtd")
          a = Array.new(r.action)
          a << :restart unless a.include?(:restart)
          a.delete(:start) if a.include?(:restart)
          r.action(a)
        end
        action :nothing
      end

      service "virtlogd" do
        action [:enable, :start]
        if node[:nova][:ha][:compute][:enabled]
          provider Chef::Provider::CrowbarPacemakerService
          supports no_crm_maintenance_mode: true
        end
        only_if { node[:platform_family] == "suse" && node[:platform_version].to_f > 12.1 }
      end
      utils_systemd_service_restart "virtlogd" do
        action node[:nova][:ha][:compute][:enabled] ? :disable : :enable
        only_if { node[:platform_family] == "suse" && node[:platform_version].to_f > 12.1 }
      end

      service "libvirtd" do
        action [:enable, :start]
        if node[:nova][:ha][:compute][:enabled]
          provider Chef::Provider::CrowbarPacemakerService
          supports no_crm_maintenance_mode: true
        end
      end
      utils_systemd_service_restart "libvirtd" do
        action node[:nova][:ha][:compute][:enabled] ? :disable : :enable
      end
    else
      service "libvirt-bin" do
        action :nothing
        supports status: true, start: true, stop: true, restart: true
      end
      utils_systemd_service_restart "libvirt-bin"

      cookbook_file "/etc/libvirt/qemu.conf" do
        owner "root"
        group "root"
        mode "0644"
        source "qemu.conf"
        notifies :restart, "service[libvirt-bin]"
      end
    end

    # kill all the libvirt default networks.
    execute "Destroy the libvirt default network" do
      command "virsh net-destroy default"
      only_if "virsh net-list |grep -q default"
    end

    link "/etc/libvirt/qemu/networks/autostart/default.xml" do
      action :delete
    end

end

nova_package "compute" do
  use_pacemaker_provider node[:nova][:ha][:compute][:enabled]
  restart_crm_resource true
  no_crm_maintenance_mode true
end

cookbook_file "/etc/nova/nova-compute.conf" do
  source "nova-compute.conf"
  owner "root"
  group "root"
  mode 0644
  notifies :restart, "service[nova-compute]"
end unless node[:platform_family] == "suse"

nova_controllers = node_search_with_cache("roles:nova-controller")

nova_controller_ips = nova_controllers.map do |nova_controller_node|
  Chef::Recipe::Barclamp::Inventory.get_network_by_type(nova_controller_node, "admin").address
end

if node[:nova]["setup_shared_instance_storage"]
  # Note: since we do not allow setting up shared storage with a cluster, we
  # know that the first controller is the right one to use (ie, the only one)
  unless nova_controllers.empty?
    mount node[:nova][:instances_path] do
      action nova_controllers[0].name != node.name ? [:mount, :enable] : [:umount, :disable]
      fstype "nfs"
      options "rw,auto"
      device nova_controller_ips[0] + ":" + node[:nova][:instances_path]
    end
  end
elsif !node[:nova]["use_shared_instance_storage"]
  unless nova_controllers.empty?
    mount node[:nova][:instances_path] do
      action [:umount, :disable]
      device nova_controller_ips[0] + ":" + node[:nova][:instances_path]
    end
  end
end

directory "#{node[:nova][:home_dir]}/.ssh" do
  mode 0o700
  owner node[:nova][:user]
  action :create
  recursive true
end

ssh_auth_keys = ""
if node["roles"].include?("nova-compute-zvm")
  ssh_auth_keys += node[:nova][:zvm][:zvm_xcat_ssh_key]
end

unless node[:nova][:compute_remotefs_sshkey].empty?
  # Create and distribute ssh keys for nova user on all compute nodes
  file "#{node[:nova][:home_dir]}/.ssh/id_ed25519" do
    mode 0o600
    owner node[:nova][:user]
    content "#{node[:nova][:compute_remotefs_sshkey]}\n"
  end

  ssh_auth_keys += %x[ssh-keygen -y -f "#{node[:nova][:home_dir]}/.ssh/id_ed25519"].chomp
end

file "#{node[:nova][:home_dir]}/.ssh/authorized_keys" do
  content ssh_auth_keys
  owner node[:nova][:user]
end

# enable or disable the ksm setting (performance)
template "/etc/default/qemu-kvm" do
  source "qemu-kvm.erb"
  variables({
    kvm: node[:nova][:kvm]
  })
  mode "0644"
end if node[:platform_family] == "debian"

template "/usr/sbin/crowbar-compute-set-sys-options" do
  source "crowbar-compute-set-sys-options.erb"
  variables({
    ksm_enabled: node[:nova][:kvm][:ksm_enabled] ? 1 : 0,
    transparent_hugepage_enabled: node[:nova][:kvm][:ksm_enabled] ? "never" : "always",
    transparent_hugepage_defrag: node[:nova][:kvm][:ksm_enabled] ? "never" : "madvise"
  })
  mode "0755"
end

cookbook_file "/etc/cron.d/crowbar-compute-set-sys-options-at-boot" do
  source "crowbar-compute-set-sys-options-at-boot"
end

execute "run crowbar-compute-set-sys-options" do
  command "/usr/sbin/crowbar-compute-set-sys-options"
end

execute "set vhost_net module" do
  command "grep -q 'vhost_net' /etc/modules || echo 'vhost_net' >> /etc/modules"
end

cinder_servers = node_search_with_cache("roles:cinder-controller")
unless cinder_servers.empty?
  cinder_server = cinder_servers[0]
  if cinder_server[:cinder][:use_multipath]
    package "multipath-tools"

    service "multipathd" do
      action [:enable, :start]
    end
    utils_systemd_service_restart "multipathd"
  end
end

# Set our availability zone
env, command_no_arg = NovaAvailabilityZone.fetch_set_az_command_no_arg(node, @cookbook_name)
command = NovaAvailabilityZone.add_arg_to_set_az_command(command_no_arg, node)

execute "Set availability zone for #{node.hostname}" do
  command command
  environment env
  timeout 60
  # Any exit code in the range 60-69 is a tempfail
  returns [0] + (60..69).to_a
  action :nothing
  subscribes :run, "execute[trigger-nova-own-az-config]", :delayed
end

# This is to trigger all the above "execute" resources to run :delayed, so that
# they run at the end of the chef-client run, after the nova service have been
# restarted (in case of a config change and if we're also a controller)
execute "trigger-nova-own-az-config" do
  command "true"
end

if node[:nova][:ha][:compute][:enabled]
  # NovaCompute ocf agent requires crudini
  package "crudini"

  # Mark the node as ready for HA compute setup
  unless node[:nova][:ha][:compute][:setup]
    node.set[:nova][:ha][:compute][:setup] = true
    node.save
  end
end

# Set iptables rules for blocking VNC Access for all but the nova-controller node.
# Using iptables u32 module to check for the first 1024 bits of a tcp packet in
# port range 5900 to 15900. Do a string matching with RFB-003 protocol to verify
# if the packets are VNC packets. Only apply the iptables rules to VNC packets.
bash "nova_compute_vncblock_reject_all" do
  code <<-EOH
    iptables -N VNCBLOCK
    iptables -I INPUT  \
       -p tcp --match multiport --dports 5900:15900 \
       -m connbytes --connbytes 0:1024 \
       --connbytes-dir both --connbytes-mode bytes \
       -m state --state ESTABLISHED \
       -m u32 --u32 "0>>22&0x3C@ 12>>26&0x3C@ 0=0x52464220" \
       -m string --algo kmp --string "RFB 003." --to 130 \
       -j VNCBLOCK
    iptables -I VNCBLOCK -p tcp -j REJECT
  EOH
  not_if "iptables -L INPUT | grep -q VNCBLOCK"
end

# Allow out packets which use VNC protocol as per RFB 003 using the u32 module
# for all possible hosts with role nova_multi_controller. This block does the
# same basic filtering as explained above but only to allow nova_multi_controller
# hosts.
nova_controller_ips.each do |nova_controller_ip|
  bash "nova_compute_vncblock_allow_#{nova_controller_ip}" do
    code <<-EOH
      iptables -I VNCBLOCK -s #{nova_controller_ip} -j ACCEPT
    EOH
    not_if "iptables -nL VNCBLOCK | grep -q #{nova_controller_ip}"
  end
end

service = "openstack-nova-compute"
if node[:nova][:resource_limits] && node[:nova][:resource_limits][service]
  limits = node[:nova][:resource_limits][service]
  action = limits.values.any? ? :create : :delete
  utils_systemd_override_limits "Resource limits for #{service}" do
    service_name service
    limits limits
    action action
  end
end
