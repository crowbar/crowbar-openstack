def upgrade(template_attrs, template_deployment, attrs, deployment)
  attrs["ssl"].delete("ca_certs")
  return attrs, deployment
end

def downgrade(template_attrs, template_deployment, attrs, deployment)
  attrs["ssl"]["ca_certs"] = template_attrs["ssl"]["ca_certs"]
  return attrs, deployment
end
