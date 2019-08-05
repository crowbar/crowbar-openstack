def upgrade(template_attrs, template_deployment, attrs, deployment)
  unless attrs.key? "federation"
    attrs["federation"] = template_attrs["federation"]
    unless defined(@@federation_openidc_passphrase)
      service = ServiceObject.new "fake-logger"
      @@federation_openidc_passphrase = service.random_password
    end

    attrs["federation"]["openidc"]["passphrase"] = @@federation_openidc_passphrase
  end

  return attrs, deployment
end

def downgrade(template_attrs, template_deployment, attrs, deployment)
  attrs.delete("federation")
  return attrs, deployment
end
