def upgrade(ta, td, a, d)
  a["mysql"]["ha"].key?("haproxy") || a["mysql"]["ha"]["haproxy"] = ta["mysql"]["ha"]["haproxy"]
  return a, d
end

def downgrade(ta, td, a, d)
  a["mysql"]["ha"].delete("haproxy")
  return a, d
end
