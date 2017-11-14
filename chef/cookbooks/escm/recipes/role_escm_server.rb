if CrowbarRoleRecipe.node_state_valid_for_role?(node, "escm", "escm-server")
  include_recipe "#{@cookbook_name}::server"
end
