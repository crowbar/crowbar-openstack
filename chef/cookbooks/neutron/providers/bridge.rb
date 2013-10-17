
action :create do
  
  case new_resource.type
  when "linuxbridge"
    updated = false
    bridge_name = "brq" + ::Neutron.get_net_id_by_name(new_resource.network_name, new_resource.neutron_cmd)[0,11]
    unless ::Nic.exists?(bridge_name):
      ::Nic::Bridge.create(bridge_name)
      updated = true
    end
    bridge = ::Nic.new(bridge_name)
    new_resource.slaves.each do |slave|
      unless bridge.slaves.any?{ |d| true if d.name == slave }
        Chef::Log.info("Enslaving #{slave} to #{bridge_name} !")
        bridge.add_slave(slave)
        updated = true
      end
      res = bridge.usurp(slave)
      if res[0].any? or res[1].any?
        updated = true
        Chef::Log.info("#{bridge_name} usurped #{res[0].join(", ")} addresses from #{slave}") unless res[0].empty?
        Chef::Log.info("#{bridge_name} usurped #{res[1].join(", ")} routes from #{slave}") unless res[1].empty?
      end
    end
    new_resource.updated_by_last_action(updated)
  end

end
