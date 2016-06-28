node[:neutron][:platform][:cisco_apic_pkgs].each { |p| package p }

if node[:neutron][:ml2_mechanism_drivers].include?("apic_gbp")
  node[:neutron][:platform][:cisco_apic_gbp_pkgs].each { |p| package p }
end

# Explicitly Stop and disable L3 and Metadata Agents if APIC is enabled
service node[:neutron][:platform][:metadata_agent_name] do
  action [:disable, :stop]
end
service node[:neutron][:platform][:l3_agent_name] do
  action [:disable, :stop]
end

aciswitches = node[:neutron][:apic_switches].to_hash
template "/etc/neutron/plugins/ml2/ml2_conf_cisco_apic.ini" do
  cookbook "neutron"
  source "ml2_conf_cisco_apic.ini.erb"
  mode "0640"
  owner "root"
  group node[:neutron][:platform][:group]
  variables(
    apic_switches: aciswitches,
    ml2_mechanism_drivers: node[:neutron][:ml2_mechanism_drivers],
    policy_drivers: "implicit_policy,apic",
    default_ip_pool: "192.168.0.0/16",
  )
  notifies :restart, "service[#{node[:neutron][:platform][:service_name]}]"
end
