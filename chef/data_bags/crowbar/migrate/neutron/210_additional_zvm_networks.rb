def upgrade ta, td, a, d
  a["zvm"]["additional_zvm_networks"] = ta["zvm"]["additional_zvm_networks"]
  return a, d
end

def downgrade ta, td, a, d
  a["zvm"].delete("additional_zvm_networks")
  return a, d
end
