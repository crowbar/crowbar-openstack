def upgrade(ta, td, a, d)
  unless a["f5"]["max_namespaces_per_tenant"].is_a? Integer
    a["f5"]["max_namespaces_per_tenant"] = ta["f5"]["max_namespaces_per_tenant"]
  end
  a["f5"].delete("route_domain_strictness_tenant")
  unless a["f5"].key? "route_domain_strictness"
    a["f5"]["route_domain_strictness"] = ta["f5"]["route_domain_strictness"]
  end

  return a, d
end

def downgrade(ta, td, a, d)
  unless ta["f5"]["max_namespaces_per_tenant"].is_a? Integer
    a["f5"]["max_namespaces_per_tenant"] = ta["f5"]["max_namespaces_per_tenant"]
  end
  if ta["f5"].key? "route_domain_strictness_tenant"
    a["f5"]["route_domain_strictness_tenant"] = ta["f5"]["route_domain_strictness_tenant"]
  end
  unless ta["f5"].key? "route_domain_strictness"
    a["f5"].delete("route_domain_strictness")
  end

  return a, d
end
