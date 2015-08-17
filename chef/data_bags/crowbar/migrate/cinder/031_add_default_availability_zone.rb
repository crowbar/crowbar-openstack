def upgrade ta, td, a, d
  unless a.has_key? "default_availability_zone"
    a["default_availability_zone"] = ta["default_availability_zone"]
  end
  return a, d
end

def downgrade ta, td, a, d
  unless ta.has_key? "default_availability_zone"
    a.delete "default_availability_zone"
  end
  return a, d
end
