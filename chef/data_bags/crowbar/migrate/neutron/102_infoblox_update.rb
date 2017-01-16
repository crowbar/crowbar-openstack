# frozen_string_literal: true
def upgrade(ta, td, a, d)
  unless a.key? "use_infoblox"
    a["use_infoblox"] = ta["use_infoblox"]
  end
  # Since we will backport this to Cloud 6, we use 'grid_defaults`, one of the
  # newly introduced keys from this migration to determine whether we are
  # dealing with a database state from its twin in Cloud 6. In that case we
  # won't touch it. If, on the other hand, we are dealing with the Cloud 5
  # version from October 2015 we'll just overwrite it since the infoblox plugin
  # changed a great deal since then.
  unless a.key?("infoblox") && a["infoblox"].key?("grid_defaults")
    a["infoblox"] = ta["infoblox"]
  end
  return a, d
end

def downgrade(ta, td, a, d)
  unless ta.key? "use_infoblox"
    a.delete("use_infoblox")
  end
  unless ta.key? "infoblox"
    a.delete("infoblox")
  end
  return a, d
end
