def upgrade(ta, td, a, d)
  a["ldap"]["user_description_attribute"] = ta["ldap"]["user_description_attribute"]
  a["ldap"]["group_members_are_ids"] = ta["ldap"]["group_members_are_ids"]
  a["ldap"]["user_enabled_emulaton_use_group_config"] =
    ta["ldap"]["user_enabled_emulaton_use_group_config"]
  a["ldap"].delete("project_tree_dn")
  a["ldap"].delete("project_filter")
  a["ldap"].delete("project_objectclass")
  a["ldap"].delete("project_domain_id_attribute")
  a["ldap"].delete("project_id_attribute")
  a["ldap"].delete("project_member_attribute")
  a["ldap"].delete("project_name_attribute")
  a["ldap"].delete("project_desc_attribute")
  a["ldap"].delete("project_enable_attribute")
  a["ldap"].delete("project_attribute_ignore")
  a["ldap"].delete("project_allow_create")
  a["ldap"].delete("project_allow_update")
  a["ldap"].delete("project_allow_delete")
  a["ldap"].delete("project_enable_emulation")
  a["ldap"].delete("project_enable_emulation_dn")
  a["ldap"].delete("role_tree_dn")
  a["ldap"].delete("role_filter")
  a["ldap"].delete("role_objectclass")
  a["ldap"].delete("role_id_attribute")
  a["ldap"].delete("role_name_attribute")
  a["ldap"].delete("role_member_attribute")
  a["ldap"].delete("role_attribute_ignore")
  a["ldap"].delete("role_allow_create")
  a["ldap"].delete("role_allow_update")
  a["ldap"].delete("role_allow_delete")
  return a, d
end

def downgrade(ta, td, a, d)
  a["ldap"].delete("user_description_attribute")
  a["ldap"].delete("group_members_are_ids")
  a["ldap"].delete("user_enabled_emulaton_use_group_config")
  a["ldap"]["project_tree_dn"] = ta["ldap"]["project_tree_dn"]
  a["ldap"]["project_filter"] = ta["ldap"]["project_filter"]
  a["ldap"]["project_objectclass"] = ta["ldap"]["project_objectclass"]
  a["ldap"]["project_domain_id_attribute"] = ta["ldap"]["project_domain_id_attribute"]
  a["ldap"]["project_id_attribute"] = ta["ldap"]["project_id_attribute"]
  a["ldap"]["project_member_attribute"] = ta["ldap"]["project_member_attribute"]
  a["ldap"]["project_name_attribute"] = ta["ldap"]["project_name_attribute"]
  a["ldap"]["project_desc_attribute"] = ta["ldap"]["project_desc_attribute"]
  a["ldap"]["project_enable_attribute"] = ta["ldap"]["project_enable_attribute"]
  a["ldap"]["project_attribute_ignore"] = ta["ldap"]["project_attribute_ignore"]
  a["ldap"]["project_allow_create"] = ta["ldap"]["project_allow_create"]
  a["ldap"]["project_allow_update"] = ta["ldap"]["project_allow_update"]
  a["ldap"]["project_allow_delete"] = ta["ldap"]["project_allow_delete"]
  a["ldap"]["project_enable_emulation"] = ta["ldap"]["project_enable_emulation"]
  a["ldap"]["project_enable_emulation_dn"] = ta["ldap"]["project_enable_emulation_dn"]
  a["ldap"]["role_tree_dn"] = ta["ldap"]["role_tree_dn"]
  a["ldap"]["role_filter"] = ta["ldap"]["role_filter"]
  a["ldap"]["role_objectclass"] = ta["ldap"]["role_objectclass"]
  a["ldap"]["role_id_attribute"] = ta["ldap"]["role_id_attribute"]
  a["ldap"]["role_name_attribute"] = ta["ldap"]["role_name_attribute"]
  a["ldap"]["role_member_attribute"] = ta["ldap"]["role_member_attribute"]
  a["ldap"]["role_attribute_ignore"] = ta["ldap"]["role_attribute_ignore"]
  a["ldap"]["role_allow_create"] = ta["ldap"]["role_allow_create"]
  a["ldap"]["role_allow_update"] = ta["ldap"]["role_allow_update"]
  a["ldap"]["role_allow_delete"] = ta["ldap"]["role_allow_delete"]
  return a, d
end
