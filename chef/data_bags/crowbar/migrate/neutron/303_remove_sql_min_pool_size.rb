def upgrade(template_attrs, template_deployment, attrs, deployment)
  attrs["sql"].delete("min_pool_size") if attrs["sql"].key? "min_pool_size"
  return attrs, deployment
end

def downgrade(template_attrs, template_deployment, attrs, deployment)
  attrs["sql"]["min_pool_size"] = template_attrs["sql"]["min_pool_size"]
  return attrs, deployment
end
