if CrowbarRoleRecipe.node_state_valid_for_role?(node, "oscm", "oscm-server")
  include_recipe "oscm::main"
end
