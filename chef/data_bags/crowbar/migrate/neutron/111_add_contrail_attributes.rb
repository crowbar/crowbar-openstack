def upgrade(ta, td, a, d)
  a["contrail"] = ta["contrail"]
  return a, d
end

def downgrade(ta, td, a, d)
  a.delete("contrail")
  return a, d
end
