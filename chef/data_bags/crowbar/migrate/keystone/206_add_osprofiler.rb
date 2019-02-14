def upgrade(template_attrs, template_deployment, attrs, deployment)
  unless attrs.key? "osprofiler"
    attrs["osprofiler"] = template_attrs["osprofiler"]
    unless defined?(@@keystone_osprofiler_hmac_keys)
      service = ServiceObject.new "fake-logger"
      @@keystone_osprofiler_hmac_keys = service.random_password
    end
    attrs["osprofiler"]["hmac_keys"] << @@keystone_osprofiler_hmac_keys
  end
  return attrs, deployment
end

def downgrade(template_attrs, template_deployment, attrs, deployment)
  attrs.delete("osprofiler")
  return attrs, deployment
end
