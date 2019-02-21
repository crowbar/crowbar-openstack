def upgrade(template_attrs, template_deployment, attrs, deployment)
  attrs["rbd"]["use_ses"] = template_attrs["rbd"]["use_ses"] unless attrs["rbd"].key? "use_ses"
  return attrs, deployment
end

def downgrade(template_attrs, template_deployment, attrs, deployment)
  attrs["rbd"].delete("use_ses")
  return attrs, deployment
end
