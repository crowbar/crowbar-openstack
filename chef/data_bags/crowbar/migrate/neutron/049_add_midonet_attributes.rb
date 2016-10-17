def upgrade(ta, td, a, d)
  unless a.key?("midonet")
    a["midonet"] = ta["midonet"]
  end
  return a, d
end

def downgrade(ta, td, a, d)
  a.delete("midonet")
  return a, d
end
