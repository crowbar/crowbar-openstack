def upgrade(ta, td, a, d)
  unless a["volume_defaults"]["netapp"].key? "max_over_subscription_ratio"
    a["volume_defaults"]["netapp"]["max_over_subscription_ratio"] = \
      ta["volume_defaults"]["netapp"]["max_over_subscription_ratio"]

    a["volumes"].each do |volume|
      next if volume["backend_driver"] != "netapp"
      volume["netapp"]["max_over_subscription_ratio"] = \
        ta["volume_defaults"]["netapp"]["max_over_subscription_ratio"]
    end
  end

  return a, d
end

def downgrade(ta, td, a, d)
  unless ta["volume_defaults"]["netapp"].key? "max_over_subscription_ratio"
    a["volume_defaults"]["netapp"].delete("max_over_subscription_ratio")
    a["volumes"].each do |volume|
      next if volume["backend_driver"] != "netapp"
      volume["netapp"].delete("max_over_subscription_ratio")
    end
  end

  return a, d
end
