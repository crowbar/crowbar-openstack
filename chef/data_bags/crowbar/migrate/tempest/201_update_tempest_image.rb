def upgrade(ta, td, a, d)
  a["tempest_test_images"]["x86_64"] = ta["tempest_test_images"]["x86_64"]
  return a, d
end

def downgrade(ta, td, a, d)
  a["tempest_test_images"]["x86_64"] = ta["tempest_test_images"]["x86_64"]
  return a, d
end

