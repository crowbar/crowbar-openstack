def upgrade(ta, td, a, d)
  a["metadata"] = ta["metadata"] unless a.key? "metadata"
  return a, d
end

def downgrade(ta, td, a, d)
  a.delete("metadata") unless ta.key? "metadata"
  return a, d
end
