def upgrade(template_attrs, template_deployment, attrs, deployment)
  key = "loadbalancer_terminate_ssl"
  template_value = template_attrs["cinder"]["ssl"][key]
  attrs["cinder"]["ssl"][key] = template_value unless attrs["cinder"]["ssl"].key? key
  return attrs, deployment
end

def downgrade(template_attrs, template_deployment, attrs, deployment)
  key = "loadbalancer_terminate_ssl"
  attrs["cinder"]["ssl"].delete(key) unless template_attrs["cinder"]["ssl"].key? key
  return attrs, deployment
end
