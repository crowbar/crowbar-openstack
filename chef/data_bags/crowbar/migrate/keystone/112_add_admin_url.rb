def upgrade(ta, td, a, d)
  a["api"]["internal_url_host"] = ta["api"]["internal_url_host"]
  # Search for all keystone nodes and update their attributes
  # based on the current endpoint data.
  # this prevents an issue where the keystone barclamp is already deployed,
  # the migration applied, and the http/https changed just after the migration,
  # making the cookbook ignore that the protocol might have changed which
  # leads to a failure to connect to keystone
  # with this new attribute, the keystone cookbook will know that the protocol
  # has changed since the last deployment and will connect to the proper endpoint
  nodes = NodeObject.find("roles:keystone-server")
  nodes.each do |node|
    next if node.normal_attrs["keystone"].nil?
    node.normal_attrs["keystone"]["endpoint"] = {
      insecure: a["ssl"]["insecure"],
      protocol: a["api"]["protocol"],
      internal_url_host: a["api"]["internal_url_host"],
      port: a["api"]["admin_port"]
    }
    node.save
  end
  return a, d
end

def downgrade(ta, td, a, d)
  a["api"].delete("internal_url_host")
  a.delete("endpoint")
  return a, d
end
