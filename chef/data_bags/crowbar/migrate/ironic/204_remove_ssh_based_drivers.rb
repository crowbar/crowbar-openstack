def upgrade(ta, td, a, d)
  a["ironic"]["enabled_drivers"] =
    a["ironic"]["enabled_drivers"].reject { |driver| driver.include?("ssh") }
  return a, d
end
