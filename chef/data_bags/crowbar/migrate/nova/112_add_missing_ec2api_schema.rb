def upgrade(ta, td, a, d)
  a["ec2-api"] = ta["ec2-api"]
  return a, d
end

def downgrade(ta, td, a, d)
  a.delete("ec2-api")
  return a, d
end
