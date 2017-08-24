def upgrade(ta, td, a, d)
  unless a["ha"].key?("monitor") do
    a["ha"]["monitor"] = {}
    a["ha"]["monitor"]["interval"] = ta["ha"]["monitor"]["interval"]
    a["ha"]["monitor"]["timeout"] = ta["ha"]["monitor"]["timeout"]
  end
  unless a["ha"].key?("start") do
    a["ha"]["start"] = {}
    a["ha"]["start"]["timeout"] = ta["ha"]["start"]["timeout"]
  end
  unless a["ha"].key?("stop") do
    a["ha"]["stop"] = {}
    a["ha"]["stop"]["timeout"] = ta["ha"]["stop"]["timeout"]
  end
  return a, d
end

def downgrade(ta, td, a, d)
  a["ha"].delete("monitor") unless ta["ha"].key?("monitor")
  a["ha"].delete("start") unless ta["ha"].key?("start")
  a["ha"].delete("stop") unless ta["ha"].key?("stop")
  return a, d
end
