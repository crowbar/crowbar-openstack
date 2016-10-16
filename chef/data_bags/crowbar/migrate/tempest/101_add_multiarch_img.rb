def upgrade(ta, td, a, d)
  a.delete("tempest_tarball")
  a["tempest_test_images"] = ta["tempest_test_images"]
  a["tempest_test_images"]["x86_64"] = a["tempest_test_image"]
  a.delete("tempest_test_image")
  return a, d
end

def downgrade(ta, td, a, d)
  a["tempest_test_image"] = a["tempest_test_images"]["x86_64"]
  a.delete("tempest_test_images")
  a["tempest_tarball"] = ta["tempest_tarball"]
  return a, d
end
