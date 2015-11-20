def upgrade(ta, td, a, d)
  unless a.key? "block_device"
    a["block_device"] = ta["block_device"]
  end
  return a, d
end

def downgrade(ta, td, a, d)
  unless ta.key? "block_device"
    a.delete("block_device")
  end
  return a, d
end
