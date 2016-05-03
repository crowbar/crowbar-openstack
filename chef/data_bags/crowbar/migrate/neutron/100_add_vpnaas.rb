def upgrade(ta, td, a, d)
  unless a.include?("use_vpnaas")
    a["use_vpnaas"] = ta["use_vpnaas"]
  end
  return a, d
end

def downgrade(ta, td, a, d)
  unless ta.include?("use_vpnaas")
    a.delete("use_vpnaas")
  end
  return a, d
end
