def upgrade(template_attrs, template_deployment, attrs, deployment)
  attrs[:amphora].delete("manage_cidr")
  return attrs, deployment
end

def downgrade(template_attrs, template_deployment, attrs, deployment)
  attrs[:amphora]["manage_cidr"] = template_attrs["manage_cidr"]
  return attrs, deployment
end
