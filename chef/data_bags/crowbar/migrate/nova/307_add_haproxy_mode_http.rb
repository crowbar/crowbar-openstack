def upgrade(t_a, t_d, attrs, deployment)
  keys = ["loadbalancer_terminate_ssl", "pemfile"]
  keys.each do |key|
    template_value = t_a["nova"]["ssl"][key]
    attrs["nova"]["ssl"][key] = template_value unless attrs["nova"]["ssl"].key? key
  end
  return attrs, deployment
end

def downgrade(t_a, t_d, attrs, deployment)
  keys = ["loadbalancer_terminate_ssl", "pemfile"]
  keys.each { |key| attrs["nova"]["ssl"].delete(key) unless t_a["nova"]["ssl"].key? key }
  return attrs, deployment
end
