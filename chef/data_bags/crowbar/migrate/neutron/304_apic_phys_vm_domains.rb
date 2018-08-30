def upgrade(template_attributes, template_deployment, attributes, deployment)
  attributes["apic"]["phys_domain"] = template_attributes["apic"]["phys_domain"]
  attributes["apic"]["vm_domains"] = template_attributes["apic"]["vm_domains"]

  return attributes, deployment
end

def downgrade(template_attributes, template_deployment, attributes, deployment)
  attributes["apic"].delete("phys_domain")
  attributes["apic"].delete("vm_domains")

  return attributes, deployment
end
