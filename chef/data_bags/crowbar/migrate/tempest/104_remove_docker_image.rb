def upgrade(ta, td, a, d)
  a.delete("tempest_test_docker_image")
  return a, d
end

def downgrade(ta, td, a, d)
  a["tempest_test_docker_image"] = ta["tempest_test_docker_image"]
  return a, d
end
