class Chef
  class Recipe
    def get_instance(type, query)
      results = search_env_filtered(:node, query)
      if results.length > 0
        instance = results[0]
        instance = node if instance.name == node.name
      else
        instance = node
      end
      instance
    end
  end
end
      
