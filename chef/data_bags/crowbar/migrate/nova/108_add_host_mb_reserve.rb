def upgrade(ta, td, a, d)
  a["scheduler"]["reserved_host_memory_mb"] = ta["scheduler"]["reserved_host_memory_mb"]
  return a, d
end

def downgrade(ta, td, a, d)
  a["scheduler"].delete("reserved_host_memory_mb")
  return a, d
end
