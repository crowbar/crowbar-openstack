# Copyright 2013 Dell, Inc.
# Copyright 2014 SUSE
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

neutron = nil
if node.attribute?(:cookbook) and node[:cookbook] == "nova"
  neutrons = search(:node, "roles:neutron-server AND roles:neutron-config-#{node[:nova][:neutron_instance]}")
  neutron = neutrons.first || raise("Neutron instance '#{node[:nova][:neutron_instance]}' for nova not found")
else
  neutron = node
end
neutron_server = node[:neutron][:neutron_server] rescue false


# Disable rp_filter
ruby_block "edit /etc/sysctl.conf for rp_filter" do
  block do
    rc = Chef::Util::FileEdit.new("/etc/sysctl.conf")
    rc.search_file_replace_line(/^net.ipv4.conf.all.rp_filter/, 'net.ipv4.conf.all.rp_filter = 0')
    rc.write_file
  end
  only_if { node[:platform] == "suse" }
end

directory "create /etc/sysctl.d for disable-rp_filter" do
  path "/etc/sysctl.d"
  mode "755"
end

disable_rp_filter_file = "/etc/sysctl.d/50-neutron-disable-rp_filter.conf"
cookbook_file disable_rp_filter_file do
  source "sysctl-disable-rp_filter.conf"
  mode "0644"
end

bash "reload disable-rp_filter-sysctl" do
  code "/sbin/sysctl -e -q -p #{disable_rp_filter_file}"
  action :nothing
  subscribes :run, resources(:cookbook_file=> disable_rp_filter_file), :delayed
end


case neutron[:neutron][:networking_plugin]
when "openvswitch", "cisco"
  neutron_agent = node[:neutron][:platform][:ovs_agent_name]
  neutron_agent_pkg = node[:neutron][:platform][:ovs_agent_pkg]
  agent_config_path = "/etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini"

  # Arrange for neutron-ovs-cleanup to be run on bootup of compute nodes only
  unless neutron.name == node.name
    if %w(debian ubuntu).include? node.platform
      cookbook_file "/etc/init.d/neutron-ovs-cleanup" do
        source "neutron-ovs-cleanup"
        mode 00755
      end
      link "/etc/rc2.d/S20neutron-ovs-cleanup" do
        to "../init.d/neutron-ovs-cleanup"
      end

      link "/etc/rc3.d/S20neutron-ovs-cleanup" do
        to "../init.d/neutron-ovs-cleanup"
      end

      link "/etc/rc4.d/S20neutron-ovs-cleanup" do
        to "../init.d/neutron-ovs-cleanup"
      end

      link "/etc/rc5.d/S20neutron-ovs-cleanup" do
        to "../init.d/neutron-ovs-cleanup"
      end
    end
  end
when "linuxbridge"
  neutron_agent = node[:neutron][:platform][:lb_agent_name]
  neutron_agent_pkg = node[:neutron][:platform][:lb_agent_pkg]
  agent_config_path = "/etc/neutron/plugins/linuxbridge/linuxbridge_conf.ini"
when "vmware"
  neutron_agent = node[:neutron][:platform][:nvp_agent_name]
  neutron_agent_pkg = node[:neutron][:platform][:nvp_agent_pkg]
  agent_config_path = "/etc/neutron/plugins/nicira/nvp.ini"
  # It is needed to have neutron-ovs-cleanup service
  ovs_agent_pkg = node[:neutron][:platform][:ovs_agent_pkg]
  ovs_config_path = "/etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini"
end


if ['openvswitch', 'cisco', 'vmware'].include? neutron[:neutron][:networking_plugin]
  if node.platform == "ubuntu"
    # If we expect to install the openvswitch module via DKMS, but the module
    # does not exist, rmmod the openvswitch module before continuing.
    if node[:neutron][:platform][:ovs_pkgs].any?{|e|e == "openvswitch-datapath-dkms"} &&
        !File.exists?("/lib/modules/#{%x{uname -r}.strip}/updates/dkms/openvswitch.ko") &&
        File.directory?("/sys/module/openvswitch")
      if IO.read("/sys/module/openvswitch/refcnt").strip != "0"
        Chef::Log.error("Kernel openvswitch module already loaded and in use! Please reboot me!")
      else
        bash "Unload non-DKMS openvswitch module" do
          code "rmmod openvswitch"
        end
      end
    end
  end

  node[:neutron][:platform][:ovs_pkgs].each { |p| package p }

  bash "Load openvswitch module" do
    code node[:neutron][:platform][:ovs_modprobe]
    not_if do ::File.directory?("/sys/module/openvswitch") end
  end
end


unless neutron[:neutron][:use_gitrepo]
  package neutron_agent_pkg do
    action :install
  end
  if neutron[:neutron][:networking_plugin] == "vmware"
    package ovs_agent_pkg
  end
else
  neutron_path = "/opt/neutron"
  venv_path = neutron[:neutron][:use_virtualenv] ? "#{neutron_path}/.venv" : nil

  neutron_agent = "neutron-openvswitch-agent"
  pfs_and_install_deps "neutron" do
    cookbook "neutron"
    cnode neutron
    virtualenv venv_path
    path neutron_path
    wrap_bins [ "neutron", "neutron-rootwrap" ]
  end

  create_user_and_dirs("neutron")

  link_service neutron_agent do
    virtualenv venv_path
    bin_name "neutron-openvswitch-agent --config-file #{agent_config_path} --config-dir /etc/neutron/"
  end

  execute "neutron_cp_policy.json" do
    command "cp /opt/neutron/etc/policy.json /etc/neutron/"
    creates "/etc/neutron/policy.json"
  end
  execute "neutron_cp_plugins" do
    command "cp -r /opt/neutron/etc/neutron/plugins /etc/neutron/plugins"
    creates "/etc/neutron/plugins"
  end
  execute "neutron_cp_rootwrap" do
    command "cp -r /opt/neutron/etc/neutron/rootwrap.d /etc/neutron/rootwrap.d"
    creates "/etc/neutron/rootwrap.d"
  end
  cookbook_file "/etc/neutron/rootwrap.conf" do
    cookbook "neutron"
    source "neutron-rootwrap.conf"
    mode 00644
    owner node[:neutron][:platform][:user]
  end
end


if ['openvswitch', 'cisco', 'vmware'].include? neutron[:neutron][:networking_plugin]
  if %w(redhat centos).include?(node.platform)
    openvswitch_service = "openvswitch"
  else
    openvswitch_service = "openvswitch-switch"
  end

  service "openvswitch_service" do
    service_name openvswitch_service
    supports :status => true, :restart => true
    action [ :start, :enable ]
  end

  unless %w(debian ubuntu).include? node.platform
    # Note: this must not be started! This service only makes sense on boot.
    service "neutron-ovs-cleanup" do
      service_name "openstack-neutron-ovs-cleanup" if %w(suse).include?(node.platform)
      action [ :enable ]
    end
  end

  # We always need br-int.  Neutron uses this bridge internally.
  execute "create_int_br" do
    command "ovs-vsctl add-br br-int"
    not_if "ovs-vsctl list-br | grep -q br-int"
  end

  # Make sure br-int is always up.
  ruby_block "Bring up the internal bridge" do
    block do
      ::Nic.new('br-int').up
    end
  end

  # Create the bridges Neutron needs.
  # Usurp config as needed.
  [ [ "nova_fixed", "fixed" ],
    [ "os_sdn", "tunnel" ],
    [ "public", "public"] ].each do |net|
    bound_if = (node[:crowbar_wall][:network][:nets][net[0]].last rescue nil)
    next unless bound_if
    name = "br-#{net[1]}"
    execute "Neutron: create #{name}" do
      command "ovs-vsctl add-br #{name}; ip link set #{name} up"
      not_if "ovs-vsctl list-br |grep -q #{name}"
    end
    next if net[1] == "tunnel"
    execute "Neutron: add #{bound_if} to #{name}" do
      command "ovs-vsctl del-port #{name} #{bound_if} ; ovs-vsctl add-port #{name} #{bound_if}"
      not_if "ovs-dpctl show system@#{name} | grep -q #{bound_if}"
    end
    ruby_block "Have #{name} usurp config from #{bound_if}" do
      block do
        target = ::Nic.new(name)
        res = target.usurp(bound_if)
        Chef::Log.info("#{name} usurped #{res[0].join(", ")} addresses from #{bound_if}") unless res[0].empty?
        Chef::Log.info("#{name} usurped #{res[1].join(", ")} routes from #{bound_if}") unless res[1].empty?
      end
    end
  end
end


include_recipe "neutron::common_config"


service neutron_agent do
  supports :status => true, :restart => true
  action [:enable, :start]
  subscribes :restart, resources("template[#{agent_config_path}]")
  subscribes :restart, resources("template[/etc/neutron/neutron.conf]")
end
