def upgrade(ta, td, a, d)
  ["admin", "service", "default"].each do |user_type|
    a[user_type]["project"] = a[user_type]["tenant"]
    a[user_type].delete("tenant")
  end
  return a, d
end

def downgrade(ta, td, a, d)
  ["admin", "service", "default"].each do |user_type|
    a[user_type]["tenant"] = a[user_type]["project"]
    a[user_type].delete("project")
  end
  return a, d
end
