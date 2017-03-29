def upgrade(ta, td, a, d)
  unless a.key?("cluster")
    # don't convert anything existing to cluster
    a["cluster"] = false
  end
  return a, d
end

def downgrade(ta, td, a, d)
  a.delete("cluster") unless ta.key?("cluster")
  return a, d
end
