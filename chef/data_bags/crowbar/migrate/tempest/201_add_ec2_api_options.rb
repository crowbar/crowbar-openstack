def upgrade(ta, td, a, d)
  a["ec2_api"] = ta["ec2_api"]
  return a, d
end

def downgrade(ta, td, a, d)
  a.delete("ec2_api")
  return a, d
end
