def upgrade(ta, td, a, d)
  a["mysql"]["bootstrap_timeout"] = ta["mysql"]["bootstrap_timeout"] unless a["mysql"]["bootstap_timeout"]
  return a, d
end

def downgrade(ta, td, a, d)
  a["mysql"].delete("bootstrap_timeout") unless ta["mysql"].key?("bootstrap_timeout")
  return a, d
end
