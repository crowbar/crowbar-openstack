def upgrade(template_attrs, template_deployment, attrs, deployment)
  attrs["api"]["protocol"] = template_attrs["api"]["protocol"]
  return attrs, deployment
end

def downgrade(template_attrs, template_deployment, attrs, deployment)
  attrs["api"].delete("protocol")
  return attrs, deployment
end
