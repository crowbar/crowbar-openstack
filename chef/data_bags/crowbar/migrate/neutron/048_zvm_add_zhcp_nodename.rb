def upgrade(ta, td, a, d)
  a["zvm"]["zvm_xcat_zhcp_nodename"] = ta["zvm"]["zvm_xcat_zhcp_nodename"]
  a["zvm"]["zvm_xcat_mgt_vswitch"] = ta["zvm"]["zvm_xcat_mgt_vswitch"]
  return a, d
end

def downgrade(ta, td, a, d)
  a["zvm"].delete("zvm_xcat_zhcp_nodename")
  a["zvm"].delete("zvm_xcat_mgt_vswitch")
  return a, d
end
