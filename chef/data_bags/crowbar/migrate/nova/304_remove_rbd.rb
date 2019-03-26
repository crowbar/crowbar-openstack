def upgrade(template_attrs, template_deployment, attrs, deployment)
  attrs.delete("rbd")
  return attrs, deployment
end

def downgrade(template_attrs, template_deployment, attrs, deployment)
  attrs["rbd"] = template_attrs["rbd"]
  return attrs, deployment
end
