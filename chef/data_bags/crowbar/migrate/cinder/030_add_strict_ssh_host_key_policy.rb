def upgrade ta, td, a, d
  a["strict_ssh_host_key_policy"] = ta["strict_ssh_host_key_policy"]
  return a, d
end

def downgrade ta, td, a, d
  a.delete "strict_ssh_host_key_policy"
  return a, d
end
