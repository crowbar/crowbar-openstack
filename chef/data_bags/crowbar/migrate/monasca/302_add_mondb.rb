def upgrade(template_attrs, template_deployment, attrs, deployment)
  unless attrs.key? "db_monapi"
    attrs["db_monapi"] = template_attrs[:db_monapi]
    service = ServiceObject.new "fake-logger"
    attrs["db_monapi"]["password"] = service.random_password
  end

  # use the database password that is already available
  if attrs.key? "master"
    if attrs["master"].key? "database_monapi_password"
      attrs["db_monapi"]["password"] = attrs["master"]["database_monapi_password"]
      attrs["master"].delete(:database_monapi_password)
    end
  end

  return attrs, deployment
end

def downgrade(template_attrs, template_deployment, attrs, deployment)
  # copy password to old place
  attrs["master"]["database_monapi_password"] = attrs["db_monapi"]["password"]
  attrs.delete("db_monapi")
  return attrs, deployment
end
