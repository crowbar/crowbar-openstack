def upgrade(ta, td, a, d)
  unless a.key? "token_expiration"
    a["token_expiration"] = ta["token_expiration"]
  end
  return a, d
end

def downgrade(ta, td, a, d)
  unless ta.key? "token_expiration"
    a.delete("token_expiration")
  end
  return a, d
end
