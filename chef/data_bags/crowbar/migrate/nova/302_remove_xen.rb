def upgrade(template_attrs, template_deployment, attrs, deployment)
  deployment["element_states"] = template_deployment["element_states"]
  deployment["element_order"] = template_deployment["element_order"]
  deployment["element_run_list_order"] = template_deployment["element_run_list_order"]

  deployment["elements"]["nova-compute-xen"] &&
    deployment["elements"].delete("nova-compute-xen")
  deployment.fetch("elements_expanded", {}).key?("nova-compute-xen") &&
    deployment["elements_expanded"].delete("nova-compute-xen")

  nodes = NodeObject.find("run_list_map:nova-compute-xen")
  nodes.each do |node|
    node.delete_from_run_list("nova-compute-xen")
    node.save
  end

  return attrs, deployment
end

def downgrade(template_attrs, template_deployment, attrs, deployment)
  deployment["element_states"] = template_deployment["element_states"]
  deployment["element_order"] = template_deployment["element_order"]
  deployment["element_run_list_order"] = template_deployment["element_run_list_order"]

  return attrs, deployment
end
