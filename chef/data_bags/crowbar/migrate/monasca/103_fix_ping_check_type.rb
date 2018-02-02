def upgrade(ta, td, a, d)
  key_pingcheck = a["agent"]["plugins"]["libvirt"].key?("ping_check")
  ta_pingcheck = ta["agent"]["plugins"]["libvirt"]["ping_check"]

  # If there is no ping_check key at all, simply migrate to current value
  unless key_pingcheck
    a["agent"]["plugins"]["libvirt"]["ping_check"] = ta_pingcheck
    return a, d
  end

  a_pingcheck = a["agent"]["plugins"]["libvirt"]["ping_check"]

  # Only override existing value if it is boolean
  a["agent"]["plugins"]["libvirt"]["ping_check"] = ta_pingcheck if
    a_pingcheck.is_a?(TrueClass) || a_pingcheck.is_a?(FalseClass)

  return a, d
end

def downgrade(ta, td, a, d)
  a["agent"]["plugins"]["libvirt"]["ping_check"] = false

  return a, d
end
