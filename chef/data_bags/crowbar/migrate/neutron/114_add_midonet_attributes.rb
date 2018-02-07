def upgrade(ta, td, a, d)
  a["midonet"] = ta["midonet"] unless a.key?("midonet")
  return a, d
end

def downgrade(ta, td, a, d)
  a.delete("midonet")
  return a, d
end
