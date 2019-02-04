def upgrade(template_attrs, template_deployment, attrs, deployment)
  attrs["elasticsearch_curator"].delete("cron_config")
  return attrs, deployment
end

def downgrade(template_attrs, template_deployment, attrs, deployment)
  attrs["elasticsearch_curator"]["cron_config"] = template_attrs["elasticsearch_curator"]["cron_config"]
  return attrs, deployment
end
