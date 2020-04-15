def upgrade(template_attrs, template_deployment, attrs, deployment)
  attrs.delete("ssl") unless template_attrs.key?("ssl")
  attrs.delete("api") unless template_attrs.key?("api")
  return attrs, deployment
end

def downgrade(template_attrs, template_deployment, attrs, deployment)
  attrs["ssl"] = template_attrs["ssl"] unless attrs.key?("ssl")
  attrs["api"] = template_attrs["api"] unless attrs.key?("api")
  return attrs, deployment
end
