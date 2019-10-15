def upgrade(template_attrs, template_deployment, attrs, deployment)
  deployment["config"]["transitions"] = template_deployment["config"]["transitions"]
  deployment["config"]["transition_list"] = template_deployment["config"]["transition_list"]
  return attrs, deployment
end

def downgrade(template_attrs, template_deployment, attrs, deployment)
  deployment["config"]["transitions"] = false
  deployment["config"]["transition_list"] = []
  return attrs, deployment
end
