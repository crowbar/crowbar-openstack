neutron = node
ml2_mech_drivers = neutron[:neutron][:ml2_mechanism_drivers]

return unless ml2_mech_drivers.include?("contrail")

if node.roles.include?("neutron-network")
  # Explicitly stop and disable dhcp and lbaas agents
  service node[:neutron][:platform][:dhcp_agent_name] do
    action [:disable, :stop]
  end

  service node[:neutron][:platform][:lbaas_agent_name] do
    action [:disable, :stop]
  end
end
