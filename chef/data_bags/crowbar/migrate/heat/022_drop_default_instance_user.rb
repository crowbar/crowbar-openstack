def upgrade(ta, td, a, d)
  a.delete("default_instance_user")
  return a, d
end

def downgrade(ta, td, a, d)
  a["default_instance_user"] = ta["default_instance_user"]
  return a, d
end
