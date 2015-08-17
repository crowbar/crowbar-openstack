def upgrade ta, td, a, d
  a["volume"]["emc"]["masking_view"] = ta["volume"]["emc"]["masking_view"]
  return a, d
end


def downgrade ta, td, a, d
  a["volume"]["emc"].delete("masking_view")
  return a, d
end
