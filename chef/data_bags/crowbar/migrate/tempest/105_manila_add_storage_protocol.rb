def upgrade(ta, td, a, d)
  a["manila"]["storage_protocol"] = ta["manila"]["storage_protocol"]
  return a, d
end

def downgrade(ta, td, a, d)
  a["manila"].delete("storage_protocol")
  return a, d
end
