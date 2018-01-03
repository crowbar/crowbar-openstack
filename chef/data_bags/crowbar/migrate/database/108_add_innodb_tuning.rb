def upgrade(ta, td, a, d)
  a["mysql"]["innodb_tunings"] = ta["mysql"]["innodb_tunings"] unless a["mysql"]["innodb_tunings"]
  return a, d
end

def downgrade(ta, td, a, d)
  a["mysql"].delete("innodb_tunings") unless ta["mysql"].key?("innodb_tunings")
  return a, d
end
