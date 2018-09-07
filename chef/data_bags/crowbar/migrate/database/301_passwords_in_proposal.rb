def upgrade(ta, td, a, d)
  # Up to now the db passwords were store only in the proposal-role not in the
  # proposal itself. So we need to initialize the proposal values from the
  # proposal role.
  role_name = d['config']['environment']
  role = Chef::Role.load(role_name) rescue nil

  service = ServiceObject.new "fake-logger"
  if role.nil?
    # role.nil? means a proposal exists but it hasn't been applied yet. In
    # this case we need to create new random passwords.

    # In case this migration gets backported we need to avoid overwriting
    # existing passwords
    a["db_maker_password"] ||= service.random_password
    a["mysql"]["server_root_password"] ||= service.random_password
    a["mysql"]["sstuser_password"] ||= service.random_password
    a["postgresql"]["password"]["postgres"] ||= service.random_password
  else
    # The existing proposal as been applied at least once, copy the
    # passwords from the propsal role into the proposal
    # Note: This migration will also be execute on the proposal
    # role itself. But that shouldn't be any problem, since we'd just
    # copy the values from the same role.

    a["db_maker_password"] ||= role.default_attributes["database"]["db_maker_password"]
    a["mysql"]["server_root_password"] ||=
      role.default_attributes["database"]["mysql"]["server_root_password"]

    # This wasn't set for non-HA deployments in the past. Just create a new
    # random password to avoid future confusion, as we now create a random
    # password in the proposal as well.
    a["mysql"]["sstuser_password"] ||=
      role.default_attributes["database"]["mysql"]["sstuser_password"] || service.random_password

    # The postgresql password is store in an override_attribute before
    # this migration. In case postgresql was not deployed the password is empty
    # We just generate a random one as the proposal create also generates one
    # independent of the choice of the deployed db backend
    a["postgresql"]["password"] ||= {}
    a["postgresql"]["password"]["postgres"] ||=
      role.override_attributes["database"]["postgresql"]["password"]["postgres"] rescue nil || service.random_password
  end

  return a, d
end

def downgrade(ta, td, a, d)
  # There is no good way to roll this back automatically, since we would remove
  # the attributes from the proposal role as well
  return a, d
end
