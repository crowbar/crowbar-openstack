def upgrade(ta, td, a, d)
  a["stack_user_domain_id"] = ""
  return a, d
end

def downgrade(ta, td, a, d)
  a.delete("stack_user_domain_id")
  return a, d
end
