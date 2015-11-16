def upgrade(ta, td, a, d)
  attr_emc = a["volume_defaults"]["emc"]
  templ_attr_emc = ta["volume_defaults"]["emc"]

  attr_emc["ecom_server_portgroups"] = templ_attr_emc["ecom_server_portgroups"]
  attr_emc["ecom_server_array"] = templ_attr_emc["ecom_server_array"]
  attr_emc["ecom_server_pool"] = templ_attr_emc["ecom_server_pool"]
  attr_emc["ecom_server_polcy"] = templ_attr_emc["ecom_server_policy"]
  attr_emc.delete("emc_storage_type")
  attr_emc.delete("masking_view")

  a["volumes"].each do |volume|
    next if volume["backend_driver"] != "emc"
    volume["emc"]["ecom_server_portgroups"] = templ_attr_emc["ecom_server_portgroups"]
    volume["emc"]["ecom_server_array"] = templ_attr_emc["ecom_server_array"]
    volume["emc"]["ecom_server_pool"] = templ_attr_emc["ecom_server_pool"]
    volume["emc"]["ecom_server_polcy"] = templ_attr_emc["ecom_server_policy"]
    volume["emc"].delete("emc_storage_type")
    volume["emc"].delete("masking_view")
  end
  return a, d
end

def downgrade(ta, td, a, d)
  attr_emc = a["volume_defaults"]["emc"]
  templ_attr_emc = ta["volume_defaults"]["emc"]

  attr_emc.delete("ecom_server_portgroups")
  attr_emc.delete("ecom_server_array")
  attr_emc.delete("ecom_server_pool")
  attr_emc.delete("ecom_server_polcy")
  attr_emc["emc_storage_type"] = templ_attr_emc["emc_storage_type"]
  attr_emc["masking_view"] = templ_attr_emc["masking_view"]

  a["volumes"].each do |volume|
    next if volume["backend_driver"] != "emc"
    volume["emc"].delete("ecom_server_portgroups")
    volume["emc"].delete("ecom_server_array")
    volume["emc"].delete("ecom_server_pool")
    volume["emc"].delete("ecom_server_polcy")
    volume["emc"]["emc_storage_type"] = templ_attr_emc["emc_storage_type"]
    volume["emc"]["masking_view"] = templ_attr_emc["masking_view"]
  end
  return a, d
end
