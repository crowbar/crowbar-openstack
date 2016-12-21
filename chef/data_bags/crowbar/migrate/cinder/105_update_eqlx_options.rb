def upgrade(ta, td, a, d)
  # new defaults
  a["volume_defaults"]["eqlx"] = ta["volume_defaults"]["eqlx"]

  # update the backends
  a["volumes"].each do |volume|
    next if volume["backend_driver"] != "eqlx"
    volume["eqlx"]["chap_username"] = volume["eqlx"]["eqlx_chap_login"]
    volume["eqlx"].delete "eqlx_chap_login"

    volume["eqlx"]["chap_password"] = volume["eqlx"]["eqlx_chap_password"]
    volume["eqlx"].delete "eqlx_chap_password"

    volume["eqlx"]["use_chap_auth"] = volume["eqlx"]["eqlx_use_chap"]
    volume["eqlx"].delete "eqlx_use_chap"
  end
  return a, d
end

def downgrade(ta, td, a, d)
  # new defaults
  a["volume_defaults"]["eqlx"] = ta["volume_defaults"]["eqlx"]

  # update the backends
  a["volumes"].each do |volume|
    next if volume["backend_driver"] != "eqlx"
    volume["eqlx"]["eqlx_chap_login"] = volume["eqlx"]["chap_username"]
    volume["eqlx"].delete "chap_username"

    volume["eqlx"]["eqlx_chap_password"] = volume["eqlx"]["chap_password"]
    volume["eqlx"].delete "chap_password"

    volume["eqlx"]["eqlx_use_chap"] = volume["eqlx"]["use_chap_auth"]
    volume["eqlx"].delete "use_chap_auth"
  end
  return a, d
end
