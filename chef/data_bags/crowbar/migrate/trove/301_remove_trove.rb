def upgrade(template_attrs, template_deployment, attrs, deployment)
  deployment["element_states"] = template_deployment["element_states"]
  deployment["element_order"] = template_deployment["element_order"]
  deployment["element_run_list_order"] = template_deployment["element_run_list_order"]

  deployment["elements"]["trove"] &&
    deployment["elements"].delete("trove")
  deployment.fetch("elements_expanded", {}).key?("trove") &&
    deployment["elements_expanded"].delete("trove")

  nodes = NodeObject.find("run_list_map:trove")
  nodes.each do |node|
    node.delete_from_run_list("trove")
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
