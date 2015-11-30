def upgrade(ta, td, a, d)
  a["vsphere"].delete("api_insecure")
  return a, d
end

def downgrade(ta, td, a, d)
  a["vsphere"]["api_insecure"] = ta["vsphere"]["api_insecure"]
  return a, d
end
