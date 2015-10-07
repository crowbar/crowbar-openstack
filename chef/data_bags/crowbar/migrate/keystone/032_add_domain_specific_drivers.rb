def upgrade ta, td, a, d
  unless a.has_key? "domain_specific_drivers"
    a["domain_specific_drivers"] = ta["domain_specific_drivers"]
  end
  unless a.has_key? "domain_config_dir"
    a["domain_config_dir"] = ta["domain_config_dir"]
  end
  return a, d
end

def downgrade ta, td, a, d
  unless ta.has_key? "domain_specific_drivers"
    a.delete("domain_specific_drivers")
  end
  unless ta.has_key? "domain_config_dir"
    a.delete("domain_config_dir")
  end
  return a, d
end
