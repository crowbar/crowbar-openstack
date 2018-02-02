def upgrade(ta, td, a, d)
  a["l3_ha"] ||= {}
  ["enabled", "max_l3_agents_per_router"].each do |attribute|
     a["l3_ha"][attribute] = ta["l3_ha"][attribute] unless a["l3_ha"].key?(attribute)
  end

  unless defined?(@@neutron_l3_ha_password)
    service = ServiceObject.new "fake-logger"
    @@neutron_l3_ha_password = service.random_password
  end
  a["l3_ha"]["password"] = @@neutron_l3_ha_password unless a["l3_ha"].key?("password")

  return a, d
end

def downgrade(ta, td, a, d)
  unless ta.key?("l3_ha")
    if a.key("l3_ha")
      ["enabled", "password", "max_l3_agents_per_router"].each do |attribute|
         a["l3_ha"].delete(attribute) unless ta["l3_ha"].key?(attribute)
      end

      a.delete("l3_ha")
    end
  end

  return a, d
end
