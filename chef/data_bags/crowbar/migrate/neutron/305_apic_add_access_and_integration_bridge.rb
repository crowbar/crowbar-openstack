def upgrade(template_attributes, template_deployment, attributes, deployment)
  attributes["apic"]["opflex"]["integration_bridge"] = template_attributes["apic"]["opflex"]["integration_bridge"]
  attributes["apic"]["opflex"]["access_bridge"] = template_attributes["apic"]["opflex"]["access_bridge"]

  return attributes, deployment
end

def downgrade(template_attributes, template_deployment, attributes, deployment)
  attributes["apic"]["opflex"].delete("integration_bridge")
  attributes["apic"]["opflex"].delete("access_bridge")

  return attributes, deployment
end
