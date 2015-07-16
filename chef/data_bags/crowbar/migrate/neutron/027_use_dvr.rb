def upgrade ta, td, a, d
  a["use_dvr"] = ta["use_dvr"]

  return a, d
end

def downgrade ta, td, a, d
  a.delete("use_dvr")

  return a, d
end
