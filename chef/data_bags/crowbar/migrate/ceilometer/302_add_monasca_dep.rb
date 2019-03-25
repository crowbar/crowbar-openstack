def upgrade(template_attrs, template_deployment, attrs, deployment)
  attrs["monasca_instance"] = template_attrs["monasca_instance"] unless attrs.key?("monasca_instance")
  return attrs, deployment
end

def downgrade(template_attrs, template_deployment, attrs, deployment)
  attrs.delete("monasca_instance") unless template_attrs.key?("monasca_instance")
  return attrs, deployment
end
