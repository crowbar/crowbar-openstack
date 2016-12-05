def upgrade(ta, td, a, d)
  a.delete("nova_instance")
  return a, d
end

def downgrade(ta, td, a, d)
  a["nova_instance"] = ta["nova_instance"]
  return a, d
end
