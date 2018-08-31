def upgrade(ta, td, a, d)
  if a["zvm"].key? "zvm_xcat_network"
    a["zvm"].delete("zvm_xcat_network")
  end

  return a, d
end

def downgrade(ta, td, a, d)
  unless a["zvm"].key? "zvm_xcat_network"
    a["zvm"]["zvm_xcat_network"] = ta["admin"]
  end

  return a, d
end
