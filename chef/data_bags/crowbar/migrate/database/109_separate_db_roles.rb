def upgrade(ta, td, a, d)
  d["element_states"] = td["element_states"]
  d["element_order"] = td["element_order"]

  if a["sql_engine"] == "mysql"
    d["elements"]["mysql-server"] = d["elements"]["database-server"]
    d["elements"]["atabase-server"] = []
    if d.fetch("elements_expanded", {}).key? "database-server"
      d["elements_expanded"]["mysql-server"] = d["elements_expanded"]["database-server"]
      d["elements_expanded"].delete("database-server")
    end

    chef_order = BarclampCatalog.chef_order("database")
    nodes = NodeObject.find("run_list_map:database-server")
    nodes.each do |node|
      node.add_to_run_list("mysql-server", chef_order,
                           td["element_states"]["mysql-server"])
      node.delete_from_run_list("database-server")
      node.save
    end
  end
  return a, d
end

def downgrade(ta, td, a, d)
  d["element_states"] = td["element_states"]
  d["element_order"] = td["element_order"]

  if a["sql_engine"] == "mysql"
    d["elements"]["database-server"] = d["elements"]["mysql-server"]
    d["elements"].delete("mysql-server")
    if d.fetch("elements_expanded", {}).key? "mysql-server"
      d["elements_expanded"]["database-server"] = d["elements_expanded"]["mysql-server"]
      d["elements_expanded"].delete("mysql-server")
    end

    chef_order = BarclampCatalog.chef_order("database")
    nodes = NodeObject.find("run_list_map:mysql-server")
    nodes.each do |node|
      node.add_to_run_list("database-server", chef_order,
                           td["element_states"]["database-server"])
      node.delete_from_run_list("mysql-server")
      node.save
    end
  end
  return a, d
end
