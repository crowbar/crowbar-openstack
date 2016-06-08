def upgrade(ta, td, a, d)
  unless a.key? "metadata"
    a["metadata"] = ta["metadata"]
  end
  return a, d
end

def downgrade(ta, td, a, d)
  unless ta.key? "metadata"
    a.delete("metadata")
  end
  return a, d
end
