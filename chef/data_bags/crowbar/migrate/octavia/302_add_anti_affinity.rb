def upgrade(template_attrs, template_deployment, attrs, deployment)
  attrs[:amphora][:enable_anti_affinity] = template_attrs[:amphora][:enable_anti_affinity] \
    if attrs[:amphora][:enable_anti_affinity].nil?
  return attrs, deployment
end

def downgrade(template_attrs, template_deployment, attrs, deployment)
  attrs[:amphora].delete("enable_anti_affinity")
  return attrs, deployment
end
