def upgrade ta, td, a, d
  unless a.key? "default_availability_zone"
    a["default_availability_zone"] = ta["default_availability_zone"]
  end
  return a, d
end

def downgrade ta, td, a, d
  unless ta.key? "default_availability_zone"
    a.delete "default_availability_zone"
  end
  return a, d
end
