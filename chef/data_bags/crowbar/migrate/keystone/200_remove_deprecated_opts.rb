def upgrade(ta, td, a, d)
  a.delete("verbose")

  a["ldap"].delete("allow_subtree_delete") if a["ldap"].key?("allow_subtree_delete")
  a["ldap"].delete("user_allow_create") if a["ldap"].key?("user_allow_create")
  a["ldap"].delete("user_allow_update") if a["ldap"].key?("user_allow_update")
  a["ldap"].delete("user_allow_delete") if a["ldap"].key?("user_allow_delete")
  return a, d
end

def downgrade(ta, td, a, d)
  a["verbose"] = ta["verbose"]

  ldap_a = a["ldap"]
  ldap_ta = ta["ldap"]
  ldap_keys = ["allow_subtree_delete",
               "user_allow_create",
               "user_allow_update",
               "user_allow_delete"]
  ldap_keys.each do |key|
    ldap_a[key] = ldap_ta[key] unless ldap_a.key?(key)
  end
  return a, d
end
