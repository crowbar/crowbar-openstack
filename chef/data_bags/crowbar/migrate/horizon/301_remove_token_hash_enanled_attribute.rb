def upgrade(template_attrs, template_deployment, attrs, deployment)
  attrs.delete("token_hash_enabled")
  return attrs, deployment
end

def downgrade(template_attrs, template_deployment, attrs, deployment)
  attrs["token_hash_enabled"] = template_attrs["token_hash_enabled"]
  return attrs, deployment
end
