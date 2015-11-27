def upgrade(ta, td, a, d)
  if a["identity"]["driver"] == "keystone.identity.backends.sql.Identity"
    a["identity"]["driver"] = ta["identity"]["driver"]
  end
  if a["assignment"]["driver"] == "keystone.assignment.backends.sql.Assignment"
    a["assignment"]["driver"] = ta["assignment"]["driver"]
  end
  if a["ldap"]["dumb_member"] == "cn=dumb,dc=example,dc=com"
    a["ldap"]["dumb_member"] = ta["ldap"]["dumb_member"]
  end
  if a["ldap"]["user_mail_attribute"] == "email"
    a["ldap"]["user_mail_attribute"] = ta["ldap"]["user_mail_attribute"]
  end
  if a["ldap"]["user_attribute_ignore"] == "tenant_id,tenants"
    a["ldap"]["user_attribute_ignore"] = ta["ldap"]["user_attribute_ignore"]
  end
  return a, d
end

def downgrade(ta, td, a, d)
  if a["identity"]["driver"] == "sql"
    a["identity"]["driver"] = ta["identity"]["driver"]
  end
  if a["assignment"]["driver"] == "sql"
    a["assignment"]["driver"] = ta["assignment"]["driver"]
  end
  if a["ldap"]["dumb_member"] == "cn=dumb,dc=nonexistent"
    a["ldap"]["dumb_member"] = ta["ldap"]["dumb_member"]
  end
  if a["ldap"]["user_mail_attribute"] == "mail"
    a["ldap"]["user_mail_attribute"] = ta["ldap"]["user_mail_attribute"]
  end
  if a["ldap"]["user_attribute_ignore"] == "default_project_id"
    a["ldap"]["user_attribute_ignore"] = ta["ldap"]["user_attribute_ignore"]
  end
  return a, d
end
