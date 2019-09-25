def upgrade(template_attrs, template_deployment, attrs, deployment)
  attrs["resource_email"] = template_attrs["resource_email"] unless attrs.key? "resource_email"
  template_project = template_attrs["resource_project"]
  attrs["resource_project"] = template_project unless attrs.key? "resource_project"
  return attrs, deployment
end

def downgrade(template_attrs, template_deployment, attrs, deployment)
  attrs.delete("resource_email") unless template_attrs.key? "resource_email"
  attrs.delete("resource_project") unless template_attrs.key? "resource_project"
  return attrs, deployment
end
