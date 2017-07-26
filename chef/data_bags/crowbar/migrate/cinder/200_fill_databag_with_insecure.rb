def upgrade(ta, td, a, d)
  # For each role, find the role, get the value of the insecure attribute,
  # generate the config and save the databag
  name = "cinder"
  ["#{name}-controller", "#{name}-volume"].each do |r|
    role = RoleObject.find_role_by_name(r)
    insecure = Openstack::DataBagConfig.insecure(name, role)
    config = {
      insecure: insecure
    }
    # as we dont have an old_role here, we just pass the role twice, wont affect anything
    # as the instance_from_role method has an || to use any of those (old_role or role)
    instance = Crowbar::DataBagConfig.instance_from_role(role, role)
    Crowbar::DataBagConfig.save("openstack", instance, name, config)
  end
  return a, d
end

def downgrade(ta, td, a, d)
  # There is no current way of removing the databag
  # not even sure if we should do it as it wont affect anything
  return a, d
end
