def upgrade ta, td, a, d
  # Old proposals had passwords created in the cookbook, so we need to migrate
  # them in the proposal and in the role. We use a class variable to set the
  # same password in the proposal and in the role.
  unless defined?(@@rabbitmq_password)
    service = ServiceObject.new "fake-logger"
    @@rabbitmq_password = service.random_password
  end

  Chef::Search::Query.new.search(:node) do |node|
    unless (node[:rabbitmq][:password] rescue nil).nil?
      unless node[:rabbitmq][:password].empty?
        @@rabbitmq_password = node[:rabbitmq][:password]
      end
      node[:rabbitmq].delete('password')
      node.save
    end
  end

  if a['password'].nil? || a['password'].empty?
    a['password'] = @@rabbitmq_password
  end

  return a, d
end

def downgrade ta, td, a, d
  return a, d
end
