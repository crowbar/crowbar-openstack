def upgrade(ta, td, a, d)
  a["agent"]["monitor_libvirt"] = ta["agent"]["monitor_libvirt"] unless
    a["agent"].key?("monitor_libvirt")

  a["agent"]["plugins"] = ta["agent"]["plugins"] unless
    a["agent"].key?("plugins")

  return a, d
end

def downgrade(ta, td, a, d)
  a["agent"].delete("monitor_libvirt") unless ta["agent"].key?("monitor_libvirt")

  a["agent"].delete("plugins") unless ta["agent"].key?("plugins")

  return a, d
end
