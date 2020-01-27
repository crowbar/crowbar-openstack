def upgrade(t_a, t_d, attrs, deployment)
  keys = ["loadbalancer_terminate_ssl", "pemfile"]
  keys.each do |key|
    template_value = t_a["cinder"]["ssl"][key]
    attrs["cinder"]["ssl"][key] = template_value unless attrs["cinder"]["ssl"].key? key
  end
  return attrs, deployment
end

def downgrade(t_a, t_d, attrs, deployment)
  keys = ["loadbalancer_terminate_ssl", "pemfile"]
  keys.each { |key| attrs["cinder"]["ssl"].delete(key) unless t_a["cinder"]["ssl"].key? key }
  return attrs, deployment
end
