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

aciswitches = node[:neutron][:apic][:apic_switches].to_hash
acivmms = node[:neutron][:apic][:apic_vmms].to_hash
template "/etc/neutron/neutron-server.conf.d/100-ml2_conf_cisco_apic.ini.conf" do
  cookbook "neutron"
  source "ml2_conf_cisco_apic.ini.erb"
  mode "0640"
  owner "root"
  group node[:neutron][:platform][:group]
  variables(
    apic_switches: aciswitches,
    apic_vmms: acivmms,
    ml2_mechanism_drivers: node[:neutron][:ml2_mechanism_drivers],
    policy_drivers: "implicit_policy,apic",
    default_ip_pool: "192.168.0.0/16",
  )
  notifies :restart, "service[#{node[:neutron][:platform][:service_name]}]"
end
