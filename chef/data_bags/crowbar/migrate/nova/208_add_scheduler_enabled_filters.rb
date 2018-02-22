def upgrade(ta, td, a, d)
  if a["scheduler"].key? "default_filters"
    a["scheduler"]["enabled_filters"] = a["scheduler"]["default_filters"]
    a["scheduler"].delete("default_filters")
  else
    a["scheduler"]["enabled_filters"] = ta["scheduler"]["enabled_filters"]
  end
  return a, d
end

def downgrade(ta, td, a, d)
  if ta["scheduler"].key? "default_filters"
    a["scheduler"]["default_filters"] = a["scheduler"]["enabled_filters"]
  end
  a["scheduler"].delete("enabled_filters")
  return a, d
end
