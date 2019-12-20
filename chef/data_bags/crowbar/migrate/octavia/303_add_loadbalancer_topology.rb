def upgrade(template_attrs, template_deployment, attrs, deployment)
  t_amphora = template_deployment[:amphora]
  attrs[:amphora][:loadbalancer_topology] = t_amphora[:loadbalancer_topology] \
    unless attrs[:amphora].key? :loadbalancer_topology
  attrs[:amphora][:spare_amphora_pool_size] = t_amphora[:spare_amphora_pool_size] \
    unless attrs[:amphora].key? :spare_amphora_pool_size
  return attrs, deployment
end

def downgrade(template_attrs, template_deployment, attrs, deployment)
  attrs[:amphora].delete(:loadbalancer_topology)
  attrs[:amphora].delete(:spare_amphora_pool_size)
  return attrs, deployment
end
