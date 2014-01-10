def upgrade ta, td, a, d
  a["volume"]["rbd"] = {}
  a["volume"]["rbd"]["pool"] = ta["volume"]["rbd"]["pool"]
  a["volume"]["rbd"]["user"] = ta["volume"]["rbd"]["user"]
  return a, d
end


def downgrade ta, td, a, d
  a["volume"].delete("rbd")
  return a, d
end
