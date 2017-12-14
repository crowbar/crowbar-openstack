def upgrade(ta, td, a, d)
  a["mnesia"] = ta["mnesia"] unless a["mnesia"]
  return a, d
end

def downgrade(ta, td, a, d)
  a.delete("mnesia") unless ta.key?("mnesia")
  return a, d
end
