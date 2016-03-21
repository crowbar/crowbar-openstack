def upgrade(ta, td, a, d)
  ta_eternus = ta["volume_defaults"]["eternus"]

  a["volumes"].each do |volume|
    next if volume["backend_driver"] != "eternus"
    volume["eternus"]["snappool"] = volume["eternus"]["pool"]
    volume["eternus"]["pool"] = ta_eternus["eternus"]["pool"]
  end
  return a, d
end

def downgrade(ta, td, a, d)
  a_eternus = a["volume_defaults"]["eternus"]
  a_eternus.delete("snappool")

  a["volumes"].each do |volume|
    next if volume["backend_driver"] != "eternus"
    volume["eternus"]["pool"] = volume["eternus"]["snappool"]
    volume["eternus"].delete("snappool")
  end
  return a, d
end
