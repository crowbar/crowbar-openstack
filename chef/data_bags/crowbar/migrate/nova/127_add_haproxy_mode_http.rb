def upgrade(template_attrs, template_deployment, attrs, deployment)
  key = "loadbalancer_terminate_ssl"
  template_value = template_attrs["nova"]["ssl"][key]
  attrs["nova"]["ssl"][key] = template_value unless attrs["nova"]["ssl"].key? key
  return attrs, deployment
end

def downgrade(template_attrs, template_deployment, attrs, deployment)
  key = "loadbalancer_terminate_ssl"
  attrs["nova"]["ssl"].delete(key) unless template_attrs["nova"]["ssl"].key? key
  return attrs, deployment
end
