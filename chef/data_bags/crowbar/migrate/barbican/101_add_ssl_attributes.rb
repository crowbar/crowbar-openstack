def upgrade(ta, td, a, d)
  a["ssl"] = ta["ssl"]
  a["api"]["protocol"] = a["api"]["ssl"] ? "https" : "http"
  a["api"].delete("ssl")
  return a, d
end

def downgrade(ta, td, a, d)
  a.delete("ssl")
  a["api"]["ssl"] = a["api"]["protocol"] == "https" ? true : false
  a["api"].delete("protocol")
  return a, d
end
