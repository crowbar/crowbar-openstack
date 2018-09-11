def upgrade(template_attributes, template_deployment, attributes, deployment)
  key = "optimize_max_conn"
  attributes[key] = template_attributes[key] unless attributes[key]
  return attributes, deployment
end

def downgrade(template_attributes, template_deployment, attributes, deployment)
  key = "optimize_max_conn"
  attributes.delete(key) unless template_attributes.key?(key)
  return attributes, deployment
end
