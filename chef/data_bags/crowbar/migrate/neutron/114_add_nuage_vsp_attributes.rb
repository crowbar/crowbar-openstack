def upgrade ta, td, a, d
  a["nuage"] = {}
  a["nuage"]["vrs_personality"] = ta["nuage"]["vrs_personality"]
  a["nuage"]["vrs_active_controller"] = ta["nuage"]["vrs_active_controller"]
  a["nuage"]["vrs_standby_controller"] = ta["nuage"]["vrs_standby_controller"]
  a["nuage"]["vsd_user"] = ta["nuage"]["vsd_user"]
  a["nuage"]["vsd_password"] = ta["nuage"]["password"]
  a["nuage"]["vsd_server"] = ta["nuage"]["server"]
  a["nuage"]["vsd_default_net_partition_name"] = ta["nuage"]["vsd_default_net_partition_name"]
  a["nuage"]["vsd_cms_id"] = ta["nuage"]["vsd_cms_id"]

  return a, d
end

def downgrade ta, td, a, d
  a.delete("nuage")
  return a, d
end

