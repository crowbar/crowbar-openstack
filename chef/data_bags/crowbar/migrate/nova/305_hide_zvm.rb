def upgrade(template_attrs, template_deployment, attrs, deployment)
  deployment["element_states"] = template_deployment["element_states"]
  deployment["element_order"] = template_deployment["element_order"]
  deployment["element_run_list_order"] = template_deployment["element_run_list_order"]

  deployment["elements"]["nova-compute-zvm"] &&
    deployment["elements"].delete("nova-compute-zvm")
  deployment.fetch("elements_expanded", {}).key?("nova-compute-zvm") &&
    deployment["elements_expanded"].delete("nova-compute-zvm")

  return attrs, deployment
end

def downgrade(template_attrs, template_deployment, attrs, deployment)
  deployment["element_states"] = template_deployment["element_states"]
  deployment["element_order"] = template_deployment["element_order"]
  deployment["element_run_list_order"] = template_deployment["element_run_list_order"]

  return attrs, deployment
end
