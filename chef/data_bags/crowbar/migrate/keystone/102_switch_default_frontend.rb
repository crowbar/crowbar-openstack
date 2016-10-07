def upgrade(ta, td, a, d)
  # newton needs the apache frontend so switch to the new default
  a["frontend"] = ta["frontend"]
  return a, d
end

def downgrade(ta, td, a, d)
  a["frontend"] = ta["frontend"]
  return a, d
end
