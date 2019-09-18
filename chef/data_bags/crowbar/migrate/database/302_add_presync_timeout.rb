def upgrade(template_attrs, template_deployment, attrs, deployment)
  unless attrs["mysql"]["presync_timeout"]
    attrs["mysql"]["presync_timeout"] = template_attrs["mysql"].key?("presync_timeout")
  end
  return attrs, deployment
end

def downgrade(template_attrs, template_deployment, attrs, deployment)
  attrs["mysql"].delete("presync_timeout") unless template_attrs["mysql"].key?("presync_timeout")
  return attrs, deployment
end
