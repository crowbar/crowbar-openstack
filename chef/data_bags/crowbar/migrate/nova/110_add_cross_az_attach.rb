def upgrade(ta, td, a, d)
  unless a.key? "cross_az_attach"
    a["cross_az_attach"] = ta["cross_az_attach"]
  end
  return a, d
end

def downgrade(ta, td, a, d)
  unless ta.key? "cross_az_attach"
    a.delete("cross_az_attach")
  end
  return a, d
end
