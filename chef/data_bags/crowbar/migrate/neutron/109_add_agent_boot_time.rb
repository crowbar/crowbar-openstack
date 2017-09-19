def upgrade(ta, td, a, d)
  a["l2pop"] = ta["l2pop"] unless a.key?("l2pop")

  return a, d
end

def downgrade(ta, td, a, d)
  a.delete("l2pop")

  return a, d
end
