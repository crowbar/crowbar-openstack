def upgrade(ta, td, a, d)
  a.delete("use_launch_instance_ng")
  return a, d
end

def downgrade(ta, td, a, d)
  a["use_launch_instance_ng"] = ta["use_launch_instance_ng"]
  return a, d
end
