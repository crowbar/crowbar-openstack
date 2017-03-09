def upgrade(ta, td, a, d)
  unless a["trust"].key? "cluster_user_trust"
    a["trust"]["cluster_user_trust"] = ta["trust"]["cluster_user_trust"]
  end
  return a, d
end

def downgrade(ta, td, a, d)
  if ta["trust"].key? "cluster_user_trust"
    a["trust"].delete("cluster_user_trust")
  end
  return a, d
end
