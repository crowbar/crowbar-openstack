def upgrade(template_attrs, template_deployment, attrs, deployment)
  attrs["apache"]["ssl_protocol"] = template_attrs["apache"]["ssl_protocol"]
  return attrs, deployment
end

def downgrade(template_attrs, template_deployment, attrs, deployment)
  attrs["apache"].delete("ssl_protocol")
  return attrs, deployment
end
