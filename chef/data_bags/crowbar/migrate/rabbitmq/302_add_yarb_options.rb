def upgrade(template_attributes, template_deployment, attributes, deployment)
  attributes["yarb"] = template_attributes["yarb"] unless attributes["yarb"]
  return attributes, deployment
end

def downgrade(template_attributes, template_deployment, attributes, deployment)
  attributes.delete("yarb") unless template_attributes.key?("yarb")
  return attributes, deployment
end
