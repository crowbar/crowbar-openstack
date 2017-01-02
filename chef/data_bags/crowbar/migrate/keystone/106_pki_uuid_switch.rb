def upgrade(ta, td, a, d)
  # This migration is required to correctly update the attribute when migrating
  # from a cloud with PKI option enabled to the new release without PKI support
  if a["signing"]["token_format"] == "PKI"
    a["signing"]["token_format"] = "UUID"
  end
  return a, d
end

def downgrade(ta, td, a, d)
  # There is no good way to roll back the above change since we
  # don't know what was set before here.
  return a, d
end
