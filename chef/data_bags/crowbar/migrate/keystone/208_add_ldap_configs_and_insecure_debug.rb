def upgrade(template_attrs, template_deployment, attrs, deployment)
  unless attrs["ldap"].key?("chase_referrals")
    attrs["ldap"]["chase_referrals"] = template_attrs["ldap"]["chase_referrals"]
  end
  attrs["domain_specific_config"].keys.each do |domain|
    unless attrs["domain_specific_config"][domain]["ldap"].key?("chase_referrals")
      attrs["domain_specific_config"][domain]["ldap"]["chase_referrals"] =
        template_attrs["domain_specific_config"]["ldap_users"]["ldap"]["chase_referrals"]
    end
  end
  attrs["insecure_debug"] = template_attrs["insecure_debug"] unless attrs.key?("insecure_debug")

  return attrs, deployment
end

def downgrade(template_attrs, template_deployment, attrs, deployment)
  attrs["ldap"].delete("chase_referrals") unless template_attrs["ldap"].key?("chase_referrals")
  unless template_attrs["domain_specific_config"]["ldap_users"]["ldap"].key?("chase_referrals")
    attrs["domain_specific_config"].keys.each do |domain|
      attrs["domain_specific_config"][domain]["ldap"].delete("chase_referrals")
    end
  end
  attrs.delete("insecure_debug") unless template_attrs.key?("insecure_debug")

  return attrs, deployment
end
