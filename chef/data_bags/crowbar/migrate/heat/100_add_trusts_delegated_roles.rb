def upgrade(ta, td, a, d)
  # Keep heat_stack_owner as a default for existing installations: operators
  # of existing clouds may have created user accounts that do not have the
  # "member" role in the proposal's default, but do have the "heat_stack_owner"
  # role (required for Heat to work). Switching trusts_delegated_roles to
  # "member" would break heat for such users.
  unless a.key? "trusts_delegated_roles"
    a["trusts_delegated_roles"] = ["heat_stack_owner"]
  end
  return a, d
end

def downgrade(ta, td, a, d)
  if a.key? "trusts_delegated_roles"
    a.delete("trusts_delegated_roles")
  end
  return a, d
end
