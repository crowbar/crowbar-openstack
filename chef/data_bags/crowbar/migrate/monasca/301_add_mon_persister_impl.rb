def upgrade(template_attrs, template_deployment, attrs, deployment)
  # this migration already happened if the mon_persister_impl key exists
  return attrs, deployment if attrs["master"].key?("mon_persister_impl")

  attrs["master"]["mon_persister_impl"] = template_attrs["master"]["mon_persister_impl"]

  return attrs, deployment
end

def downgrade(template_attrs, template_deployment, attrs, deployment)
  attrs["master"].delete("mon_persister_impl")

  return attrs, deployment
end
