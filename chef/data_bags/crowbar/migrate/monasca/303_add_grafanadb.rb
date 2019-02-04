def upgrade(template_attrs, template_deployment, attrs, deployment)
  unless attrs.key? "db_grafana"
    attrs[:db_grafana] = template_attrs[:db_grafana]
    service = ServiceObject.new "fake-logger"
    attrs[:db_grafana][:password] = service.random_password
  end
  # use the database password that is already available
  if attrs[:master].key? "database_grafana_password"
    attrs[:db_grafana][:password] = attrs[:master][:database_grafana_password]
    attrs[:master].delete(:database_grafana_password)
  end
  return attrs, deployment
end

def downgrade(template_attrs, template_deployment, attrs, deployment)
  # copy password to old place
  attrs[:master][:database_grafana_password] = attrs[:db_grafana][:password]
  attrs.delete(:db_grafana)
  return attrs, deployment
end
