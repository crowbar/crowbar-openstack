def upgrade(ta, td, a, d)
  z = a["zvm"]

  unless z.key? "zvm_user_default_password"
    z["zvm_user_default_password"] = ta["zvm"]["zvm_user_default_password"]
  end
  unless z.key? "zvm_user_default_privilege"
    z["zvm_user_default_privilege"] = ta["zvm"]["zvm_user_default_privilege"]
  end
  unless z.key? "zvm_reachable_timeout"
    z["zvm_reachable_timeout"] = ta["zvm"]["zvm_reachable_timeout"]
  end

  return a, d
end

def downgrade(ta, td, a, d)
  z = a["zvm"]

  unless ta["zvm"].key? "zvm_user_default_password"
    z.delete("zvm_user_default_password")
  end
  unless ta["zvm"].key? "zvm_user_default_privilege"
    z.delete("zvm_user_default_privilege")
  end
  unless ta["zvm"].key? "zvm_reachable_timeout"
    z.delete("zvm_reachable_timeout")
  end

  return a, d
end
