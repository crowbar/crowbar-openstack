def upgrade(template_attrs, template_deployment, attrs, deployment)
  unless attrs["volume_defaults"]["rbd"].key? "use_ses"
    attrs["volume_defaults"]["rbd"]["use_ses"] = template_attrs["volume_defaults"]["rbd"]["use_ses"]
  end
  attrs["volumes"].each do |backend|
    next unless backend.key? "rbd"
    next if backend["rbd"].key? "use_ses"
    backend["rbd"]["use_ses"] = template_attrs["volume_defaults"]["rbd"]["use_ses"]
  end
  return attrs, deployment
end

def downgrade(template_attrs, template_deployment, attrs, deployment)
  attrs["volume_defaults"]["rbd"].delete("use_ses")
  attrs["volumes"].each do |backend|
    next unless backend.key? "rbd"
    backend["rbd"].delete("use_ses")
  end
  return attrs, deployment
end
