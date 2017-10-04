def upgrade(ta, td, a, d)
  unless a.key? "compute_remotefs_sshkey"
    a["compute_remotefs_sshkey"] = %x[
      t=$(mktemp)
      rm -f $t
      ssh-keygen -q -t ed25519 -N "" -f $t
      cat $t
      rm -f $t ${t}.pub
    ]
  end

  return a, d
end

def downgrade(ta, td, a, d)
  unless ta.key? "compute_remotefs_sshkey"
    a.delete("compute_remotefs_sshkey")
  end
  return a, d
end
