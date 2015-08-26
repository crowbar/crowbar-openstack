def upgrade(ta, td, a, d)
  unless a.has_key? "rpc_response_timeout"
    a["rpc_response_timeout"] = ta["rpc_response_timeout"]
  end
  return a, d
end

def downgrade(ta, td, a, d)
  unless ta.has_key? "rpc_response_timeout"
    a.delete("rpc_response_timeout")
  end
  return a, d
end
