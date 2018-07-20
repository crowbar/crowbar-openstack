def upgrade(ta, td, a, d)
  db_engine = a["sql_engine"]

  # 'ha' hash needs to be moved under 'postgresql' to keep it consistent with mysql
  if db_engine == "postgresql"
    a["postgresql"]["ha"] = a["ha"]
  else
    a["postgresql"]["ha"] = ta["postgresql"]["ha"]
  end
  a.delete("ha") if a.key? "ha"

  d["element_states"] = td["element_states"]
  d["element_order"] = td["element_order"]

  if db_engine == "mysql"
    # For the time of upgrade, we're adding new 'mysql-server role', while old 'database-server'
    # is reserved for existing postgresql setup.
    # For users that already have mysql (mariadb) deployed with 'database-server' role, we need to
    # adapt the role assignments so the code that is looking for 'mysql-server' instances always finds
    # correct mysql nodes.
    d["elements"]["mysql-server"] = d["elements"]["database-server"]
    d["elements"]["database-server"] = []
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
