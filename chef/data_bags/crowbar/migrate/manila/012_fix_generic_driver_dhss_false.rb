# ta->template_attributes, td->template_deployment, a->attributes, d->deployment
def upgrade(ta, td, a, d)
  a["share_defaults"]["generic"] = ta["share_defaults"]["generic"]

  # update shares
  a["shares"].each do |share|
    next if share["backend_driver"] != "generic"
    # removed options
    share["generic"].delete("driver_handles_share_servers")
    share["generic"].delete("service_image_name")
    share["generic"].delete("path_to_public_key")
    share["generic"].delete("neutron_net_id")
    share["generic"].delete("neutron_subnet_id")
    # service_instance_user is no longer optional!
    unless share["generic"].key? "service_instance_user"
      share["generic"]["service_instance_user"] =
        ta["share_defaults"]["generic"]["service_instance_user"]
    end
    # new required options
    share["generic"]["service_instance_name_or_id"] =
      ta["share_defaults"]["generic"]["service_instance_name_or_id"]
    share["generic"]["service_net_name_or_ip"] =
      ta["share_defaults"]["generic"]["service_net_name_or_ip"]
    share["generic"]["tenant_net_name_or_ip"] =
      ta["share_defaults"]["generic"]["tenant_net_name_or_ip"]
  end
  return a, d
end

def downgrade(ta, td, a, d)
  a["share_defaults"]["generic"] = ta["share_defaults"]["generic"]

  # update shares
  a["shares"].each do |share|
    next if share["backend_driver"] != "generic"
    share["generic"]["driver_handles_share_servers"] =
      ta["share_defaults"]["generic"]["driver_handles_share_servers"]
    share["generic"]["service_image_name"] =
      ta["share_defaults"]["generic"]["service_image_name"]
    share["generic"].delete("service_instance_name_or_id")
    share["generic"].delete("service_net_name_or_ip")
    share["generic"].delete("tenant_net_name_or_ip")
    share["generic"].delete("share_volume_fstype")
  end
  return a, d
end
