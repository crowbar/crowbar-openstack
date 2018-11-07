def upgrade_neutron(tattr, tdep, attr, dep)
  key = "report_interval"
  attr[key] = tattr[key] unless attr.key? key

  key = "agent_down_time"
  attr[key] = tattr[key] unless attr.key? key
end

def downgrade_neutron(tattr, tdep, attr, dep)
  attr.delete("report_interval") if tattr.key? "report_interval"
  attr.delete("agent_down_time") if tattr.key? "agent_down_time"
end

def upgrade_sql(tattr, tdep, attr, dep)
  parent_key = "sql"
  attr[parent_key] = tattr[parent_key] unless attr.key? parent_key
  key = "connection_recycle_time"
  attr[parent_key][key] = tattr[parent_key][key] unless attr[parent_key].key? key
  key = "connection_parameters"
  attr[parent_key][key] = tattr[parent_key][key] unless attr[parent_key].key? key
end

def downgrade_sql(tattr, tdep, attr, dep)
  parent_key = "sql"
  key = "connection_recycle_time"
  attr[parent_key].delete(key) if tattr[parent_key].key? key

  key = "connection_parameters"
  attr[parent_key].delete(key) if tattr[parent_key].key? key
end

def upgrade_network_log(tattr, tdep, attr, dep)
  parent_key = "network_log"
  attr[parent_key] = tattr[parent_key] unless attr.key? parent_key
  key = "rate_limit"
  attr[parent_key][key] = tattr[parent_key][key] unless attr[parent_key].key? key
  key = "burst_limit"
  attr[parent_key][key] = tattr[parent_key][key] unless attr[parent_key].key? key
  key = "local_output_log_base"
  attr[parent_key][key] = tattr[parent_key][key] unless attr[parent_key].key? key
end

def downgrade_network_log(tattr, tdep, attr, dep)
  parent_key = "network_log"
  attr[parent_key].delete("rate_limit") if tattr[parent_key].key? "rate_limit"
  attr[parent_key].delete("burst_limit") if tattr[parent_key].key? "burst_limit"

  key = "local_output_log_base"
  attr[parent_key].delete(key) if tattr[parent_key].key? key

  attr.delete(parent_key) if tattr.key? parent_key
end

def upgrade_dhcp(tattr, tdep, attr, dep)
  parent_key = "dhcp"
  attr[parent_key] = tattr[parent_key] unless attr.key? parent_key

  key = "dhcp_renewal_time"
  attr[parent_key][key] = tattr[parent_key][key] unless attr[parent_key].key? key
  key = "dhcp_rebinding_time"
  attr[parent_key][key] = tattr[parent_key][key] unless attr[parent_key].key? key

  subparent_key = "ovs"
  key = "ovsdb_debug"
  attr[parent_key][subparent_key][key] = tattr[parent_key][subparent_key][key] unless
    attr[parent_key][subparent_key].key? key

  key = "ovsdb_timeout"
  attr[parent_key][subparent_key][key] = tattr[parent_key][subparent_key][key] unless
    attr[parent_key][subparent_key].key? key

  key = "bridge_mac_table_size"
  attr[parent_key][subparent_key][key] = tattr[parent_key][subparent_key][key] unless
    attr[parent_key][subparent_key].key? key
end

def downgrade_dhcp(tattr, tdep, attr, dep)
  parent_key = "dhcp"
  attr[parent_key].delete("dhcp_renewal_time") if tattr[parent_key].key? "dhcp_renewal_time"
  attr[parent_key].delete("dhcp_rebinding_time") if tattr[parent_key].key? "dhcp_rebinding_time"

  subparent_key = "ovs"
  key = "ovsdb_debug"
  attr[parent_key][subparent_key].delete(key) if tattr[parent_key][subparent_key].key? key

  key = "ovsdb_timeout"
  attr[parent_key][subparent_key].delete(key) if tattr[parent_key][subparent_key].key? key

  key = "bridge_mac_table_size"
  attr[parent_key][subparent_key].delete(key) if tattr[parent_key][subparent_key].key? key

  attr[parent_key].delete(subparent_key) if tattr[parent_key].key? subparent_key

  attr.delete(parent_key) if tattr.key? parent_key
end

def upgrade(tattr, tdep, attr, dep)
  upgrade_neutron(tattr, tdep, attr, dep)
  upgrade_sql(tattr, tdep, attr, dep)
  upgrade_network_log(tattr, tdep, attr, dep)
  upgrade_dhcp(tattr, tdep, attr, dep)

  attr["sql"].delete("min_pool_size") if attr["sql"].key? "min_pool_size"
  attr["ovs"].delete("ovsdb_interface") if attr["ovs"].key? "ovsdb_interface"

  return attr, dep
end

def downgrade(tattr, tdep, attr, dep)
  downgrade_neutron(tattr, tdep, attr, dep)
  downgrade_sql(tattr, tdep, attr, dep)
  downgrade_network_log(tattr, tdep, attr, dep)
  downgrade_dhcp(tattr, tdep, attr, dep)

  attr["sql"]["min_pool_size"] = tattr["sql"]["min_pool_size"]
  attr["ovs"]["ovsdb_interface"] = tattr["ovs"]["ovsdb_interface"]

  return attr, dep
end
