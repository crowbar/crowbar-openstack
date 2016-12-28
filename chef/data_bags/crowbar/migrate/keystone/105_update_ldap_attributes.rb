def upgrade(ta, td, a, d)
  a["ldap"].delete("group_attribute_ignore")
  a["ldap"].delete("group_allow_create")
  a["ldap"].delete("group_allow_update")
  a["ldap"].delete("group_allow_delete")
  a["ldap"].delete("use_dumb_member")
  a["ldap"].delete("dumb_member")
  a["ldap"]["group_desc_attribute"] = ta["ldap"]["group_desc_attribute"]
  a["ldap"]["user_additional_attribute_mapping"] = ta["ldap"]["user_additional_attribute_mapping"]
  a["ldap"]["group_additional_attribute_mapping"] = ta["ldap"]["group_additional_attribute_mapping"]
  a["ldap"]["group_ad_nesting"] = ta["ldap"]["group_ad_nesting"]
  a["ldap"]["pool_size"] = ta["ldap"]["pool_size"]
  a["ldap"]["pool_retry_max"] = ta["ldap"]["pool_retry_max"]
  a["ldap"]["pool_retry_delay"] = ta["ldap"]["pool_retry_delay"]
  a["ldap"]["pool_connection_timeout"] = ta["ldap"]["pool_connection_timeout"]
  a["ldap"]["pool_connection_lifetime"] = ta["ldap"]["pool_connection_lifetime"]
  a["ldap"]["use_auth_pool"] = ta["ldap"]["use_auth_pool"]
  a["ldap"]["auth_pool_size"] = ta["ldap"]["auth_pool_size"]
  a["ldap"]["auth_pool_connection_lifetime"] = ta["ldap"]["auth_pool_connection_lifetime"]
  return a, d
end

def downgrade(ta, td, a, d)
  a["ldap"]["group_attribute_ignore"] = ta["ldap"]["group_attribute_ignore"]
  a["ldap"]["group_allow_create"] = ta["ldap"]["group_allow_create"]
  a["ldap"]["group_allow_update"] = ta["ldap"]["group_allow_update"]
  a["ldap"]["group_allow_delete"] = ta["ldap"]["group_allow_delete"]
  a["ldap"]["use_dumb_member"] = ta["ldap"]["use_dumb_member"]
  a["ldap"]["dumb_member"] = ta["ldap"]["dumb_member"]
  a["ldap"].delete("group_desc_attribute")
  a["ldap"].delete("user_additional_attribute_mapping")
  a["ldap"].delete("group_additional_attribute_mapping")
  a["ldap"].delete("group_ad_nesting")
  a["ldap"].delete("pool_size")
  a["ldap"].delete("pool_retry_max")
  a["ldap"].delete("pool_retry_delay")
  a["ldap"].delete("pool_connection_timeout")
  a["ldap"].delete("pool_connection_lifetime")
  a["ldap"].delete("use_auth_pool")
  a["ldap"].delete("auth_pool_size")
  a["ldap"].delete("auth_pool_connection_lifetime")
  return a, d
end
