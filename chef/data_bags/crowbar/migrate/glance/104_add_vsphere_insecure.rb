def upgrade(ta, td, a, d)
  a["vsphere"]["insecure"] = ta["vsphere"]["insecure"]
  return a, d
end

def downgrade(ta, td, a, d)
  a["vsphere"].delete("insecure")
  return a, d
end
