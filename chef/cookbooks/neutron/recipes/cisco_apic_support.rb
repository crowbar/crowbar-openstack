#
# Copyright 2016 SUSE Linux GmBH
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

node[:neutron][:platform][:cisco_apic_pkgs].each { |p| package p }

if node[:neutron][:ml2_mechanism_drivers].include?("apic_gbp")
  node[:neutron][:platform][:cisco_apic_gbp_pkgs].each { |p| package p }
end

# Empty the config file to avoid confusion (it may be a symlink, due to some
# old code we had)
old_config = "/etc/neutron/plugins/ml2/ml2_conf_cisco_apic.ini"
link old_config do
  action :delete
  only_if "test -L #{old_config}"
end
file old_config do
  owner "root"
  group node[:neutron][:platform][:group]
  mode "0640"
  content "# Please use config file snippets in /etc/neutron/neutron.conf.d/.\n" \
          "# See /etc/neutron/README.config for more details.\n"
end

# remove old snippet that was created previously
file "/etc/neutron/neutron-server.conf.d/100-ml2_conf_cisco_apic.ini.conf" do
  action :delete
end

aciswitches = node[:neutron][:apic][:apic_switches].to_hash
acivmms = node[:neutron][:apic][:apic_vmms]

# If using VMWare vcenter as one of the compute hosts.
# distributed dhcp and metadata cannot work since these
# functions conflict with vcenter functionality.
if acivmms.find { |vmm| vmm[:vmm_type].downcase == "vmware"}
  apic_optimized_dhcp = false 
  apic_optimized_metadata = false
else
  apic_optimized_dhcp = node[:neutron][:apic][:optimized_dhcp]
  apic_optimized_metadata = node[:neutron][:apic][:optimized_metadata]
end

template node[:neutron][:ml2_cisco_apic_config_file] do
  cookbook "neutron"
  source "ml2_conf_cisco_apic.ini.erb"
  mode "0640"
  owner "root"
  group node[:neutron][:platform][:group]
  variables(
    vpc_pairs: node[:neutron][:apic][:vpc_pairs],
    apic_switches: aciswitches,
    optimized_dhcp: apic_optimized_dhcp,
    optimized_metadata: apic_optimized_metadata,
    apic_vmms: acivmms,
    ml2_mechanism_drivers: node[:neutron][:ml2_mechanism_drivers],
    policy_drivers: "implicit_policy,apic",
    default_ip_pool: "192.168.0.0/16"
  )
  notifies :restart, "service[#{node[:neutron][:platform][:service_name]}]"
end
