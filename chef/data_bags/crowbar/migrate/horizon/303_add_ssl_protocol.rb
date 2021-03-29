def upgrade(template_attrs, template_deployment, attrs, deployment)
  unless attrs["apache"].key? "ssl_protocol"
    attrs["apache"]["ssl_protocol"] = template_attrs["apache"]["ssl_protocol"]
  return attrs, deployment
end

def downgrade(template_attrs, template_deployment, attrs, deployment)
  unless template_attrs["apache"].key? "ssl_protocol"
    attrs["apache"].delete("ssl_protocol")
  return attrs, deployment
end
