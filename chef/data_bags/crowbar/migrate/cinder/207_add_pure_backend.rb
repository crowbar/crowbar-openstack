def upgrade(taa, tdd, aaa, ddd)
  aaa["volume_defaults"]["pure"] = taa["volume_defaults"]["pure"]
  return aaa, ddd
end

def downgrade(taa, tdd, aaa, ddd)
  aaa["volume_defaults"].delete("pure")
  return aaa, ddd
end
