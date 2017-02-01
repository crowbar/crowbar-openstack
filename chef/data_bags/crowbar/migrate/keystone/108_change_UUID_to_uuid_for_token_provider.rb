def upgrade(ta, td, a, d)
  if a["signing"]["token_format"] == "UUID"
    a["signing"]["token_format"] = "uuid"
  end
  return a, d
end

def downgrade(ta, td, a, d)
  a["signing"]["token_format"] = "UUID"
  return a, d
end
