def upgrade(template_attrs, template_deployment, attrs, deployment)
  attrs["kafka"]["topics"] = template_attrs["kafka"]["topics"]
  return attrs, deployment
end

def downgrade(template_attrs, template_deployment, attrs, deployment)
  attrs["kafka"].delete("topics")
  return attrs, deployment
end
