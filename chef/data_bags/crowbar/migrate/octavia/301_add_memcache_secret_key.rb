def upgrade(template_attrs, template_deployment, attrs, deployment)
  if attrs["memcache_secret_key"].nil? || attrs["memcache_secret_key"].empty?
    service = ServiceObject.new "fake-logger"
    attrs["memcache_secret_key"] = service.random_password
  end
  return attrs, deployment
end

def downgrade(template_attrs, template_deployment, attrs, deployment)
  attrs.delete("memcache_secret_key")
  return attrs, deployment
end
