def upgrade(ta, td, a, d)
  unless a["trustee"].key?("cluster_user_trust")
    a["trustee"]["cluster_user_trust"] = ta["trustee"]["cluster_user_trust"]
  end
  return a, d
end

def downgrade(ta, td, a, d)
  unless ta["trustee"].key?("cluster_user_trust")
    a["trustee"].delete("cluster_user_trust")
  end
  return a, d
end
