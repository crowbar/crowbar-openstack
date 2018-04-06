def upgrade(template_attributes, template_deployment, attributes, deployment)
  attributes["l3_ha"] ||= {}
  ["enabled", "max_l3_agents_per_router"].each do |attribute|
    attributes["l3_ha"][attribute] = template_attributes["l3_ha"][attribute] unless attributes["l3_ha"].key?(attribute)
  end

  unless defined?(@@neutron_l3_ha_password)
    service = ServiceObject.new "fake-logger"
    @@neutron_l3_ha_password = service.random_password
  end
  attributes["l3_ha"]["password"] = @@neutron_l3_ha_password unless attributes["l3_ha"].key?("password")

  return attributes, deployment
end

def downgrade(template_attributes, template_deployment, attributes, deployment)
  unless template_attributes.key?("l3_ha")
    if attributes.key("l3_ha")
      ["enabled", "password", "max_l3_agents_per_router"].each do |attribute|
        attributes["l3_ha"].delete(attribute) unless template_attributes["l3_ha"].key?(attribute)
      end

      attributes.delete("l3_ha")
    end
  end

  return attributes, deployment
end
