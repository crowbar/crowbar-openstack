def upgrade(template_attrs, template_deployment, attrs, deployment)
  attrs["log_api"]["protocol"] = template_attrs["log_api"]["protocol"]
  return attrs, deployment
end

def downgrade(template_attrs, template_deployment, attrs, deployment)
  attrs["log_api"].delete("protocol")
  return attrs, deployment
end
