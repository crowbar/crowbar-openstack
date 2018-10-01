def upgrade(template_attributes, template_deployment, attributes, deployment)
  key = "enable_queue_mirroring"
  attributes[key] = template_attributes[key] unless attributes.key? key
  return attributes, deployment
end

def downgrade(template_attributes, template_deployment, attributes, deployment)
  key = "enable_queue_mirroring"
  attributes.delete(key) unless template_attributes.key? key
  return attributes, deployment
end
