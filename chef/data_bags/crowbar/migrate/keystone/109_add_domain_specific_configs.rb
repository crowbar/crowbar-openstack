def upgrade(ta, td, a, d)
  a["domain_specific_config"] = ta["domain_specific_config"]
  return a, d
end

def downgrade(ta, td, a, d)
  a.delete("domain_specific_config")
  return a, d
end
