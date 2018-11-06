def upgrade(template_attrs, template_deployment, attrs, deployment)
  attrs["neutron"]["sql"].delete("min_pool_size")
  return attrs, deployment
end

def downgrade(template_attrs, template_deployment, attrs, deployment)
  attrs["neutron"]["sql"]["min_pool_size"] = template_attrs["neutron"]["sql"]["min_pool_size"]
  return attrs, deployment
end
