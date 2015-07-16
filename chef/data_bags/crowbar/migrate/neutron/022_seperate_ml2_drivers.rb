def upgrade ta, td, a, d
  if a["networking_mode"]
    a["ml2_type_drivers"] = [a["networking_mode"]]
    a["ml2_type_drivers_default_provider_network"] = a["networking_mode"]
    a["ml2_type_drivers_default_tenant_network"] = a["networking_mode"]
  else
    a["ml2_type_drivers"] = ta["ml2_type_drivers"]
    a["ml2_type_drivers_default_provider_network"] = ta["ml2_type_drivers_default_provider_network"]
    a["ml2_type_drivers_default_tenant_network"] = ta["ml2_type_drivers_default_tenant_network"]
  end

  if a["networking_plugin"] == "linuxbridge"
    a["networking_plugin"] = "ml2"
    a["ml2_mechanism_drivers"] = ["linuxbridge"]
  elsif a["networking_plugin"] == "openvswitch"
    a["networking_plugin"] = "ml2"
    a["ml2_mechanism_drivers"] = ["openvswitch"]
  elsif a["networking_plugin"] == "cisco"
    a["networking_plugin"] = "ml2"
    a["ml2_mechanism_drivers"] = ["openvswitch", "cisco_nexus"]
  elsif a["networking_plugin"] == "vmware"
    a["networking_plugin"] = "vmware"
  else
    a["networking_plugin"] = ta["networking_plugin"]
    a["ml2_mechanism_drivers"] = ta["ml2_mechanism_drivers"]
  end

  a.delete("networking_mode")

  return a, d
end

def downgrade ta, td, a, d
  if a.has_key? "ml2_type_drivers"
    if a["ml2_type_drivers"].include? "vlan"
      a["networking_mode"] = "vlan"
    elsif a["ml2_type_drivers"].include? "gre"
      a["networking_mode"] = "gre"
    else
      a["networking_mode"] = ta["networking_mode"]
    end
  else
    a["networking_mode"] = ta["networking_mode"]
  end

  if a["networking_plugin"] == "ml2"
    if a["ml2_mechanism_drivers"].include? "linuxbridge"
      a["networking_plugin"] = "linuxbridge"
    elsif a["ml2_mechanism_drivers"].include? "openvswitch"
      a["networking_plugin"] = "openvswitch"
    elsif a["ml2_mechanism_drivers"].include? "cisco_nexus"
      a["networking_plugin"] = "cisco"
    else
      a["networking_plugin"] = ta["networking_plugin"]
    end
  end

  a.delete("ml2_type_drivers")
  a.delete("ml2_mechanism_drivers")
  a.delete("ml2_type_drivers_default_provider_network")
  a.delete("ml2_type_drivers_default_tenant_network")
  return a, d
end
