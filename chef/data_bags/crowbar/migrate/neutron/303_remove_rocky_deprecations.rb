def upgrade(template_attrs, template_deployment, attrs, deployment)
  attrs["sql"].delete("min_pool_size")
  attrs["ovs"].delete("ovsdb_interface")
  return attrs, deployment
end

def downgrade(template_attrs, template_deployment, attrs, deployment)
  attrs["sql"]["min_pool_size"] = template_attrs["sql"]["min_pool_size"]
  attrs["ovs"]["ovsdb_interface"] = template_attrs["ovs"]["ovsdb_interface"]
  return attrs, deployment
end
