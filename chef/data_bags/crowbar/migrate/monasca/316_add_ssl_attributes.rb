def upgrade(template_attrs, template_deployment, attrs, deployment)
  attrs["ssl"] = template_attrs["ssl"]
  return attrs, deployment
end

def downgrade(template_attrs, template_deployment, attrs, deployment)
  attrs.delete("ssl")
  return attrs, deployment
end
