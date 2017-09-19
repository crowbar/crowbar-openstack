def upgrade(ta, td, a, d)
  a["rpc_workers"] = ta["rpc_workers"] unless a.key?("rpc_workers")

  return a, d
end

def downgrade(ta, td, a, d)
  a.delete("rpc_workers")

  return a, d
end
