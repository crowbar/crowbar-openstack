def upgrade(template_attrs, template_deployment, attrs, deployment)
  attrs["token_format"] = "fernet" if attrs["token_format"] == "uuid"
  return attrs, deployment
end

def downgrade(template_attrs, template_deployment, attrs, deployment)
  # downgrade is not possible
  return attrs, deployment
end
