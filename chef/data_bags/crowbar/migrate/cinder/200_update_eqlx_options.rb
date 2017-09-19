def upgrade(ta, td, a, d)
  # new defaults
  a["volume_defaults"]["eqlx"]["ssh_conn_timeout"] = \
    ta["volume_defaults"]["eqlx"]["ssh_conn_timeout"]
  a["volume_defaults"]["eqlx"].delete "eqlx_cli_timeout"

  # update the backends
  a["volumes"].each do |volume|
    next if volume["backend_driver"] != "eqlx"
    volume["eqlx"]["ssh_conn_timeout"] = volume["eqlx"]["eqlx_cli_timeout"]
    volume["eqlx"].delete "eqlx_cli_timeout"
  end
  return a, d
end

def downgrade(ta, td, a, d)
  # new defaults
  a["volume_defaults"]["eqlx"] = ta["volume_defaults"]["eqlx"]

  # update the backends
  a["volumes"].each do |volume|
    next if volume["backend_driver"] != "eqlx"
    volume["eqlx"]["eqlx_cli_timeout"] = volume["eqlx"]["ssh_conn_timeout"]
    volume["eqlx"].delete "ssh_conn_timeout"
  end
  return a, d
end
