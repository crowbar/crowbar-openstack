def upgrade(ta, td, a, d)
  a["crossdomain"] = ta["crossdomain"]
  return a, d
end

def downgrade(ta, td, a, d)
  a.delete("crossdomain")
  return a, d
end
