def upgrade(template_attrs, template_deployment, attrs, deployment)
  unless attrs.key? "osprofiler"
    attrs["osprofiler"] = template_attrs["osprofiler"]
    unless defined?(@@osprofiler_hmac_keys)
      service = ServiceObject.new "fake-logger"
      @@osprofiler_hmac_keys = service.random_password
    end
    attrs["osprofiler"]["hmac_keys"] << @@osprofiler_hmac_keys
  end
  return attrs, deployment
end

def downgrade(template_attrs, template_deployment, attrs, deployment)
  attrs.delete("osprofiler")
  return attrs, deployment
end
