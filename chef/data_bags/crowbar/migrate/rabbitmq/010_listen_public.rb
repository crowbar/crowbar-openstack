def upgrade ta, td, a, d
  a["listen_public"] = ta["listen_public"]
  return a, d
end

def downgrade ta, td, a, d
  a.delete("listen_public")
  return a, d
end
