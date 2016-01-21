def upgrade(ta, td, a, d)
  unless a.key? "show_storage_location"
    a["show_storage_location"] = ta["show_storage_location"]
  end
  return a, d
end

def downgrade(ta, td, a, d)
  unless ta.key? "show_storage_location"
    a.delete("show_storage_location")
  end
  return a, d
end
