def upgrade(ta, td, a, d)
  return a, d
end

def downgrade(ta, td, a, d)
  if a["signing"]["token_format"] == "fernet"
    a["signing"]["token_format"] = "UUID"
  end
  return a, d
end
