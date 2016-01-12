def upgrade(ta, td, a, d)
  a["zvm"]["zvm_xcat_ssh_key"] = ta["zvm"]["zvm_xcat_ssh_key"]
  return a, d
end

def downgrade(ta, td, a, d)
  a["zvm"].delete("zvm_xcat_ssh_key")
  return a, d
end
