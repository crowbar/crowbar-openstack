def upgrade(template_attrs, template_deployment, attrs, deployment)
  deployment["element_states"] = template_deployment["element_states"]
  deployment["element_order"] = template_deployment["element_order"]
  deployment["element_run_list_order"] = template_deployment["element_run_list_order"]

  deployment["elements"]["neutron-sdn-cisco-aci-agents"] &&
    deployment["elements"].delete("neutron-sdn-cisco-aci-agents")
  deployment.fetch("elements_expanded", {}).key?("neutron-sdn-cisco-aci-agents") &&
    deployment["elements_expanded"].delete("neutron-sdn-cisco-aci-agents")

  return attrs, deployment
end

def downgrade(template_attrs, template_deployment, attrs, deployment)
  deployment["element_states"] = template_deployment["element_states"]
  deployment["element_order"] = template_deployment["element_order"]
  deployment["element_run_list_order"] = template_deployment["element_run_list_order"]

  return attrs, deployment
end
