def upgrade(ta, td, a, d)
  unless a.key? "use_infoblox"
    a["use_infoblox"] = ta["use_infoblox"]
  end
  unless a.key? "infoblox"
    a["infoblox"] = ta["infoblox"]
  end
  return a, d
end

def downgrade(ta, td, a, d)
  unless ta.key? "use_infoblox"
    a.delete("use_infoblox")
  end
  unless ta.key? "infoblox"
    a.delete("infoblox")
  end
  return a, d
end
