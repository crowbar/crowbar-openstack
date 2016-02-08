def upgrade(ta, td, a, d)
  # This migration (if part of the release) will only run when upgrading
  # from Tex. Switch keystone to use UUID tokens after the upgrade for those
  # systems to avoid CVE-2015-7546 by default.
  if a["signing"]["token_format"] == "PKI"
    a["signing"]["token_format"] = ta["signing"]["token_format"]
  end
  return a, d
end

def downgrade(ta, td, a, d)
  # There is no good way to roll back the above change since we
  # don't know what was set before here.
  return a, d
end
