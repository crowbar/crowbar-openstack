def upgrade(ta, td, a, d)
  unless a.key? "pxe_append_params"
    a["pxe_append_params"] = ta["pxe_append_params"]
  end

  return a, d
end

def downgrade(ta, td, a, d)
  a.delete("pxe_append_params")
  return a, d
end
