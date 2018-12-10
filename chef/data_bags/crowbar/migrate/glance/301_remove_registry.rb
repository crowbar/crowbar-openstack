def upgrade(template_attrs, template_deployment, attrs, deployment)
  attrs.delete("registry")
  return attrs, deployment
end

def downgrade(template_attrs, template_deployment, attrs, deployment)
  attrs["registry"] = template_attrs["registry"]
  return attrs, deployment
end
