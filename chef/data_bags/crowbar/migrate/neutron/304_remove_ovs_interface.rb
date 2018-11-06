def upgrade(template_attrs, template_deployment, attrs, deployment)
  attrs["ovs"].delete("ovsdb_interface") if attrs["ovs"].key? "ovsdb_interface"
  return attrs, deployment
end

def downgrade(template_attrs, template_deployment, attrs, deployment)
  attrs["ovs"]["ovsdb_interface"] = template_attrs["ovs"]["ovsdb_interface"]
  return attrs, deployment
end
