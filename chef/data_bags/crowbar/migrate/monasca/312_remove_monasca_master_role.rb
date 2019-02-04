def upgrade(template_attrs, template_deployment, attrs, deployment)
  deployment["element_states"] = template_deployment["element_states"]
  deployment["element_order"] = template_deployment["element_order"]
  deployment["element_run_list_order"] = template_deployment["element_run_list_order"]

  deployment["elements"]["monasca-master"] &&
    deployment["elements"].delete("monasca-master")
  deployment.fetch("elements_expanded", {}).key?("monasca-master") &&
    deployment["elements_expanded"].delete("monasca-master")

  nodes = NodeObject.find("run_list_map:monasca-master")
  nodes.each do |node|
    node.delete_from_run_list("monasca-master")
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
