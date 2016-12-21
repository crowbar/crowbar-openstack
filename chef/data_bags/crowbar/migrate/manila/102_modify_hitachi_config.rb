# template_attributes, template_deployment, attributes, deployment
def upgrade(ta, td, a, d)
  # defaults
  a["share_defaults"]["hitachi"] = ta["share_defaults"]["hitachi"]
  # shares
  a["shares"].each do |share|
    next unless share["backend_driver"] == "hitachi"
    ["hds_hnas_cluster_admin_ip0", "hds_hnas_evs_id", "hds_hnas_evs_ip",
     "hds_hnas_ip", "hds_hnas_file_system_name", "hds_hnas_password", "hds_hnas_ssh_private_key",
     "hds_hnas_stalled_job_timeout", "hds_hnas_user"].each do |attr|
      share["hitachi"][attr.gsub("hds", "hitachi")] = share["hitachi"][attr]
      share["hitachi"].delete(attr)
    end
  end
  return a, d
end

def downgrade(ta, td, a, d)
  # defaults
  a["share_defaults"]["hitachi"] = ta["share_defaults"]["hitachi"]
  # shares
  a["shares"].each do |share|
    next unless share["backend_driver"] == "hitachi"
    ["hds_hnas_cluster_admin_ip0", "hds_hnas_evs_id", "hds_hnas_evs_ip",
     "hds_hnas_ip", "hds_hnas_file_system_name", "hds_hnas_password", "hds_hnas_ssh_private_key",
     "hds_hnas_stalled_job_timeout", "hds_hnas_user"].each do |attr|
      attr_modified = attr.gsub("hds", "hitachi")
      share["hitachi"][attr] = share["hitachi"][attr_modified]
      share["hitachi"].delete(attr_modified)
    end
  end
  return a, d
end
