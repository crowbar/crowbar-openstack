def upgrade(template_attrs, template_deployment, attrs, deployment)
  attrs.delete("tempest_adm_username")
  attrs.delete("tempest_adm_password")
  return attrs, deployment
end

def downgrade(template_attrs, template_deployment, attrs, deployment)
  attrs["tempest_adm_username"] = template_attrs["tempest_adm_username"]
  attrs["tempest_adm_password"] = template_attrs["tempest_adm_password"]
  return attrs, deployment
end
