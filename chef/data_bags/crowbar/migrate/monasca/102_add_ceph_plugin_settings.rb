def upgrade(ta, td, a, d)
  a["agent"]["monitor_ceph"] = ta["agent"]["monitor_ceph"] unless
    a["agent"].key?("monitor_ceph")

  return a, d
end

def downgrade(ta, td, a, d)
  a["agent"].delete("monitor_ceph") unless ta["agent"].key?("monitor_ceph")

  return a, d
end
