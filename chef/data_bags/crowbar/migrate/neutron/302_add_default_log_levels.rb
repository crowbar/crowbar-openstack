def upgrade(template_attributes, template_deployment, attributes, deployment)
  key = "default_log_levels"
  attributes[key] = template_attributes[key] unless attributes.key? key
  return attributes, deployment
end

def downgrade(template_attributes, template_deployment, attributes, deployment)
  key = "default_log_levels"
  attributes.delete(key) unless template_attributes.key? key
  return attributes, deployment
end
