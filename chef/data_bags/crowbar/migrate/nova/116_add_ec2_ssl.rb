def upgrade(ta, td, a, d)
  a["ec2-api"]["ssl"] = ta["ec2-api"]["ssl"]
  return a, d
end

def downgrage(ta, td, a, d)
  a["ec2-api"].delete("ssl")
  return a, d
end
