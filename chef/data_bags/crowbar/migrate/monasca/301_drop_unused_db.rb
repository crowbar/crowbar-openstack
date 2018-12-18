def upgrade(template_attrs, template_deployment, attrs, deployment)
  attrs.delete("db")
  return attrs, deployment
end

def downgrade(template_attrs, template_deployment, attrs, deployment)
  attrs["db"] = template_attrs["db"]
  return attrs, deployment
end
