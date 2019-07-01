def upgrade(template_attributes, template_deployment, attributes, deployment)
  ["floating_dns_domain", "dns_domain"].each do |key|
    attributes[key] = attributes[key] + "." unless attributes[key].end_with? "."
  end
  return attributes, deployment
end

def downgrade(template_attributes, template_deployment, attributes, deployment)
  return attributes, deployment
end
