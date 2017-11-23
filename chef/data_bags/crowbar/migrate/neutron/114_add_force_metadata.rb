def upgrade(ta, td, a, d)
  a["force_metadata"] = ta["force_metadata"] unless a.key? "force_metadata"
  return a, d
end

def downgrade(ta, td, a, d)
  a.delete("force_metadata") unless ta.key? "force_metadata"
  return a, d
end
