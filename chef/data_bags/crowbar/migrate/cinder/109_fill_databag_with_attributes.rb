def upgrade(ta, td, a, d)
  # Find the role, get the value of the insecure attribute and save the databag
  role = RoleObject.find_role_by_name("cinder-config-default")
  config = a
  # as we dont have an old_role here, we just pass the role twice, wont affect anything
  # as the instance_from_role method has an || to use any of those (old_role or role)
  instance = Crowbar::DataBagConfig.instance_from_role(role, role)
  Crowbar::DataBagConfig.save("openstack", instance, "cinder", config)
  return a, d
end

def downgrade(ta, td, a, d)
  # There is no current way of removing the databag
  # not even sure if we should do it as it won't affect anything
  return a, d
end
