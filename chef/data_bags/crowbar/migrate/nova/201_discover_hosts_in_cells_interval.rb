def upgrade(ta, td, a, d)
  a["scheduler"]["discover_hosts_in_cells_interval"] = \
    ta["scheduler"]["discover_hosts_in_cells_interval"]
  return a, d
end

def downgrade(ta, td, a, d)
  a["scheduler"].delete("discover_hosts_in_cells_interval")
  return a, d
end
