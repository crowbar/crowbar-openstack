neutron = nil
if node.attribute?(:cookbook) && node[:cookbook] == "nova"
  neutrons = search(:node, "roles:neutron-server AND \
                    roles:neutron-config-#{node[:nova][:neutron_instance]}")
  neutron = neutrons.first || raise("Neutron instance '#{node[:nova][:neutron_instance]}' \
                                    for nova not found")
else
  neutron = node
end

ml2_mech_drivers = neutron[:neutron][:ml2_mechanism_drivers]
ml2_type_drivers = neutron[:neutron][:ml2_type_drivers]

if ml2_mech_drivers.include?("cisco_apic_ml2")
  agent_config_path = "/etc/neutron/plugins/ml2/openvswitch_agent.ini"

  node[:neutron][:platform][:cisco_apic_pkgs].each { |p| package p }
  node[:neutron][:platform][:cisco_opflex_ovs_pkgs].each { |p| package p }
  service node[:network][:ovs_service] do
    supports status: true, restart: true
    action [:start, :enable]
  end
  # apply configurations to compute node
  if node.roles.include?("nova-compute-kvm")
    node[:neutron][:platform][:cisco_opflex_pkgs].each { |p| package p }
    # include neutron::common_config only now, after we've installed packages
    include_recipe "neutron::common_config"

    template agent_config_path do
      cookbook "neutron"
      source "openvswitch_agent.ini.erb"
      owner "root"
      group node[:neutron][:platform][:group]
      mode "0640"
      variables(
        ml2_type_drivers: ml2_type_drivers,
        tunnel_types: "",
        use_l2pop: false,
        dvr_enabled: false,
        bridge_mappings: ""
      )
    end

    # Update config file from template
    opflex_agent_conf = "/etc/opflex-agent-ovs/conf.d/10-opflex-agent-ovs.conf"
    template opflex_agent_conf do
      cookbook "neutron"
      source "10-opflex-agent-ovs.conf.erb"
      mode "0755"
      owner "root"
      group neutron[:neutron][:platform][:group]
      variables(
        opflex_apic_domain_name: neutron[:neutron][:apic][:system_id],
        hostname: node[:hostname],
        socketgroup: neutron[:neutron][:platform][:group],
        opflex_peer_ip: "10.0.0.30",
        opflex_peer_port: "8009",
        opflex_remote_ip: "10.0.0.32",
        opflex_remote_port: "8472",
        ml2_type_drivers: neutron[:neutron][:ml2_type_drivers]
      )
    end
    service "neutron-opflex-agent" do
      action [:enable, :start]
      subscribes :restart, resources("template[#{agent_config_path}]")
    end
    service "agent-ovs" do
      action [:enable, :start]
      subscribes :restart, resources("template[#{opflex_agent_conf}]")
    end
  end
end
