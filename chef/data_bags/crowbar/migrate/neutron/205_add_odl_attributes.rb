def upgrade(ta, td, a, d)
  unless a.key? "odl"
    a["odl"] = ta["odl"]
  end
  return a, d
end

def downgrade(ta, td, a, d)
  unless ta.key? "odl"
    a.delete("odl")
  end
  return a, d
end
