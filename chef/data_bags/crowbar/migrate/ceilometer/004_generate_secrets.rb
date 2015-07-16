def upgrade ta, td, a, d
  # Old proposals had passwords created in the cookbook, so we need to migrate
  # them in the proposal and in the role. We use a class variable to set the
  # same password in the proposal and in the role.
  service = ServiceObject.new "fake-logger"
  unless defined?(@@ceilometer_db_password)
    @@ceilometer_db_password = service.random_password
  end
  unless defined?(@@ceilometer_metering_secret)
    @@ceilometer_metering_secret = service.random_password
  end

  Chef::Search::Query.new.search(:node) do |node|
    dirty = false
    unless (node[:ceilometer][:db][:password] rescue nil).nil?
      unless node[:ceilometer][:db][:password].empty?
        @@ceilometer_db_password = node[:ceilometer][:db][:password]
      end
      node[:ceilometer][:db].delete('password')
      dirty = true
    end
    unless (node[:ceilometer][:metering_secret] rescue nil).nil?
      unless node[:ceilometer][:metering_secret].empty?
        @@ceilometer_metering_secret = node[:ceilometer][:metering_secret]
      end
      node[:ceilometer].delete('metering_secret')
      dirty = true
    end
    node.save if dirty
  end

  if a['db']['password'].nil? || a['db']['password'].empty?
    a['db']['password'] = @@ceilometer_db_password
  end
  if a['metering_secret'].nil? || a['metering_secret'].empty?
    a['metering_secret'] = @@ceilometer_metering_secret
  end

  return a, d
end

def downgrade ta, td, a, d
  a.delete('metering_secret')
  return a, d
end
