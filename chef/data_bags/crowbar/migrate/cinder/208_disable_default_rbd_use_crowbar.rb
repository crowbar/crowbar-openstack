def upgrade(template_attrs, template_deployment, attrs, deployment)
  attrs["volume_defaults"]["rbd"]["use_crowbar"] = template_attrs["volume_defaults"]["rbd"]["use_crowbar"]
  return attrs, deployment
end

def downgrade(template_attrs, template_deployment, attrs, deployment)
  attrs["volume_defaults"]["rbd"]["use_crowbar"] = template_attrs["volume_defaults"]["rbd"]["use_crowbar"]
  return attrs, deployment
end
