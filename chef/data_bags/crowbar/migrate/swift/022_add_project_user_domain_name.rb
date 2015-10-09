def upgrade(ta, td, a, d)
  a["dispersion"]["project_domain_name"] = ta["dispersion"]["project_domain_name"]
  a["dispersion"]["user_domain_name"] = ta["dispersion"]["user_domain_name"]
  return a, d
end

def downgrade(ta, td, a, d)
  a["dispersion"].delete("project_domain_name")
  a["dispersion"].delete("user_domain_name")
  return a, d
end
