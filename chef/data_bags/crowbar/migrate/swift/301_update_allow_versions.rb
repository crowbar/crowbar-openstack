def upgrade(template_attrs, template_deployment, attrs, deployment)
  attrs["allow_versioned_writes"] = attrs["allow_versions"]
  attrs.delete("allow_versions")
  return attrs, deployment
end

def downgrade(template_attrs, template_deployment, attrs, deployment)
  attrs.delete("allow_versioned_writes")
  attrs["allow_versions"] = template_attrs["allow_versions"]
  return attrs, deployment
end
