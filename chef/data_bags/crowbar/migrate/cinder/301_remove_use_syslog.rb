def upgrade(template_attrs, template_deployment, attrs, deployment)
  attrs.delete("use_syslog")
  return attrs, deployment
end

def downgrade(template_attrs, template_deployment, attrs, deployment)
  attrs["use_syslog"] = template_attrs["use_syslog"]
  return attrs, deployment
end
