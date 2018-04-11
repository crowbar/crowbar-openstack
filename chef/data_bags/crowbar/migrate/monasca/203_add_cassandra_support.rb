def upgrade(ta, td, a, d)
  # this migration already happened if the tsdb key exists
  return a, d if a["master"].key?("tsdb")

  a["master"]["tsdb"] = ta["master"]["tsdb"]

  # Use a class variable, since migrations are run twice.
  unless defined?(@@cassandra_admin_password)
    service = ServiceObject.new "fake-logger"
    @@cassandra_admin_password = service.random_password
  end

  a["master"]["cassandra_admin_password"] = @@cassandra_admin_password

  # Retain value of old influxdb password fields
  a["master"]["tsdb_mon_api_password"] = a["master"]["influxdb_mon_api_password"]
  a["master"]["tsdb_mon_persister_password"] = a["master"]["influxdb_mon_persister_password"]

  a["master"].delete("influxdb_mon_api_password")
  a["master"].delete("influxdb_mon_persister_password")

  return a, d
end

def downgrade(ta, td, a, d)
  a["master"]["influxdb_mon_api_password"] = a["master"]["tsdb_mon_api_password"]
  a["master"]["influxdb_mon_persister_password"] = a["master"]["tsdb_mon_persister_password"]

  a["master"].delete("cassandra_admin_password")
  a["master"].delete("tsdb")
  a["master"].delete("tsdb_mon_persister_password")
  a["master"].delete("tsdb_mon_api_password")

  return a, d
end
