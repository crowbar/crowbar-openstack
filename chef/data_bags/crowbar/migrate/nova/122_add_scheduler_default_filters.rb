def upgrade(ta, td, a, d)
  a["scheduler"]["default_filters"] = ta["scheduler"]["default_filters"]
  return a, d
end

def downgrade(ta, td, a, d)
  a["scheduler"].delete("default_filters")
  return a, d
end
