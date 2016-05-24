node[:neutron][:platform][:cisco_apic_pkgs].each { |p| package p }

if node[:neutron][:ml2_mechanism_drivers].include?("cisco_apic_ml2")
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
    )
    notifies :restart, "service[#{node[:neutron][:platform][:service_name]}]"
  end
end
