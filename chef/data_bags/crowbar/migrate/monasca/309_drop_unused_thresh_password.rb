def upgrade(template_attrs, template_deployment, attrs, deployment)
  attrs["master"].delete("database_thresh_password")
  return attrs, deployment
end

def downgrade(template_attrs, template_deployment, attrs, deployment)
  attrs["master"]["database_thresh_password"] = template_attrs["master"]["database_thresh_password"]
  return attrs, deployment
end
