def upgrade(ta, td, a, d)
  a["resource_limits"] = ta["resource_limits"] unless a["resource_limits"]
  return a, d
end

def downgrade(ta, td, a, d)
  a.delete("resource_limits") unless ta.key?("resource_limits")
  return a, d
end
