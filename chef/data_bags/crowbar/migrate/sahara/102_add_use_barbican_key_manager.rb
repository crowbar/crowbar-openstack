def upgrade(ta, td, a, d)
  unless a.key?("use_barbican_key_manager")
    a["use_barbican_key_manager"] = ta["use_barbican_key_manager"]
  end
  return a, d
end

def downgrade(ta, td, a, d)
  unless ta.key?("use_barbican_key_manager")
    a.delete("use_barbican_key_manager")
  end
  return a, d
end
