def upgrade(template_attrs, template_deployment, attrs, deployment)
  attrs["osprofiler"]["connection_string"] = template_attrs["osprofiler"]["connection_string"]
  return attrs, deployment
end

def downgrade(template_attrs, template_deployment, attrs, deployment)
  attrs["osprofiler"].delete("connection_string")
  return attrs, deployment
end
