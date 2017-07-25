def upgrade(ta, td, a, d)
  unless a.key? "keymgr_fixed_key"
    a["keymgr_fixed_key"] = ta["keymgr_fixed_key"]
  end
  return a, d
end

def downgrade(ta, td, a, d)
  unless ta.key? "keymgr_fixed_key"
    a.delete("keymgr_fixed_key")
  end
  return a, d
end
