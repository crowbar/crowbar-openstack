def upgrade(template_attributes, template_deployment, attributes, deployment)
  key = "max_threads_per_process"
  attributes["kvm"][key] = template_attributes["kvm"][key] unless attributes["kvm"].key? key
  return attributes, deployment
end

def downgrade(template_attributes, template_deployment, attributes, deployment)
  key = "max_threads_per_process"
  attributes["kvm"].delete(key) unless template_attributes["kvm"].key? key
  return attributes, deployment
end
