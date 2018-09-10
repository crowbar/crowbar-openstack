def upgrade(template_attrs, template_deployment, attrs, deployment)
  deployment["element_states"] = template_deployment["element_states"]
  deployment["element_order"] = template_deployment["element_order"]
  deployment["element_run_list_order"] = template_deployment["element_run_list_order"]

  deployment["elements"]["ec2-api"] &&
    deployment["elements"].delete("ec2-api")
  deployment.fetch("elements_expanded", {}).key?("ec2-api") &&
    deployment["elements_expanded"].delete("ec2-api")

  nodes = NodeObject.find("run_list_map:ec2-api")
  nodes.each do |node|
    node.delete_from_run_list("ec2-api")
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
