def upgrade(template_attributes, template_deployment, attributes, deployment)
  key = "use_rbd_ephemeral"
  attributes[key] = template_attributes[key] unless attributes.key? key
  return attributes, deployment
end

def downgrade(template_attributes, template_deployment, attributes, deployment)
  key = "use_rbd_ephemeral"
  attributes.delete(key) unless template_attributes.key? key
  return attributes, deployment
end
