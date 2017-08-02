def upgrade(ta, td, a, d)
  # Check if the proposal is active. If its not then we dont need to do anything
  # with the databag as it will be filled by the deployment
  prop = Proposal.where(barclamp: "rabbitmq").first
  unless prop.nil?
    return a, d unless prop.active?
  end

  # Find the role, get all the values and save the databag
  role = RoleObject.find_role_by_name("rabbitmq-config-default")
  node = NodeObject.find("roles:rabbitmq-config-default").first
  address = node["rabbitmq"]["address"]

  client_ca_certs = if a["ssl"]["enabled"] && !a["ssl"]["insecure"]
    a["ssl"]["client_ca_certs"]
  end

  port = if a["ssl"]["enabled"]
    a["ssl"]["port"]
  else
    a["port"]
  end

  config = {
    address: address,
    port: port,
    user: a["user"],
    password: a["password"],
    vhost: a["vhost"],
    use_ssl: a["ssl"]["enabled"],
    client_ca_certs: client_ca_certs,
    url: "rabbit://#{a["user"]}:#{a["password"]}@#{address}:#{port}/#{a["vhost"]}"
  }
  # as we dont have an old_role here, we just pass the role twice, wont affect anything
  # as the instance_from_role method has an || to use any of those (old_role or role)
  instance = Crowbar::DataBagConfig.instance_from_role(role, role)
  Crowbar::DataBagConfig.save("openstack", instance, "rabbitmq", config)
  return a, d
end

def downgrade(ta, td, a, d)
  # There is no current way of removing the databag
  # not even sure if we should do it as it won't affect anything
  return a, d
end
