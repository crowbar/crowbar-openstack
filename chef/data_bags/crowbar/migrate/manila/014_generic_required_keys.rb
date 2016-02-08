# ta->template_attributes, td->template_deployment, a->attributes, d->deployment
def upgrade(ta, td, a, d)
  # update shares
  a["shares"].each do |share|
    next if share["backend_driver"] != "generic"
    unless share["generic"].key? "service_instance_password"
      share["generic"]["service_instance_password"] =
        ta["share_defaults"]["generic"]["service_instance_password"]
    end
    unless share["generic"].key? "path_to_private_key"
      share["generic"]["path_to_private_key"] =
        ta["share_defaults"]["generic"]["path_to_private_key"]
    end
  end
  return a, d
end

def downgrade(ta, td, a, d)
  return a, d
end
