def upgrade(template_attrs, template_deployment, attrs, deployment)
  attrs["policy_file"].delete("orchestration")
  return attrs, deployment
end

def downgrade(template_attrs, template_deployment, attrs, deployment)
  attrs["policy_file"]["orchestration"] = template_attrs["policy_file"]["orchestration"]
  return attrs, deployment
end
