def upgrade(template_attrs, template_deployment, attrs, deployment)
  attrs["tsdb"] = attrs["master"]["tsdb"]
  attrs["cassandra"] = template_attrs["cassandra"]
  attrs["cassandra"]["admin_password"] = attrs["master"]["cassandra_admin_password"]
  attrs["master"].delete("tsdb")
  attrs["master"].delete("cassandra_admin_password")
  return attrs, deployment
end

def downgrade(template_attrs, template_deployment, attrs, deployment)
  attrs["master"]["tsdb"] = attrs["tsdb"]
  attrs["master"]["cassandra_admin_password"] = attrs["cassandra"]["admin_password"]
  attrs.delete("tsdb")
  attrs.delete("cassandra")
  return attrs, deployment
end
