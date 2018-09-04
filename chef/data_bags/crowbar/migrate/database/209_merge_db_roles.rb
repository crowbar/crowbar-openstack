def upgrade(ta, td, a, d)
  a["ha"] = ta["ha"] unless a.key? "ha"

  # Cookbooks expect the 'enabled' flag under high level 'ha' map
  # - only during the upgrade it was moved under 'ha/mysql'
  if a["mysql"] && a["mysql"]["ha"]
    a["ha"]["enabled"] = a["mysql"]["ha"]["enabled"] if a["mysql"]["ha"].key?("enabled")
    a["mysql"]["ha"].delete("enabled")
  end

  a["postgresql"].delete("ha") if a["postgresql"] && a["postgresql"].key?("ha")

  if d["elements"].key? "mysql-server"
    d["elements"]["database-server"] = d["elements"]["mysql-server"]
    d["elements"].delete("mysql-server")
    if d.fetch("elements_expanded", {}).key? "mysql-server"
      d["elements_expanded"]["database-server"] = d["elements_expanded"]["mysql-server"]
      d["elements_expanded"].delete("mysql-server")
    end

    # Make sure mysql-server role is gone from all places
    d["element_states"] = td["element_states"]
    d["element_order"] = td["element_order"]

    chef_order = BarclampCatalog.chef_order("database")
    nodes = NodeObject.find("run_list_map:mysql-server")
    nodes.each do |node|
      node.add_to_run_list("database-server", chef_order,
                           td["element_states"]["database-server"])
      node.delete_from_run_list("mysql-server")
      node.save
    end
  end

  # Delete mysql-server role if it exists
  role = Chef::Role.load("mysql-server") rescue nil
  role.destroy unless role.nil?

  return a, d
end

def downgrade(ta, td, a, d)
  # No role splitting needed now; it already has suppport in SOC7 via migration 109
  return a, d
end
