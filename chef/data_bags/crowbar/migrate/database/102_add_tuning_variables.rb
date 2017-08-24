def upgrade(ta, td, a, d)
  a["mysql"]["innodb_buffer_pool_size"] = ta["mysql"]["innodb_buffer_pool_size"]
  a["mysql"]["max_connections"] = ta["mysql"]["max_connections"]
  a["mysql"]["tmp_table_size"] = ta["mysql"]["tmp_table_size"]
  a["mysql"]["max_heap_table_size"] = ta["mysql"]["max_heap_table_size"]
  return a, d
end

def downgrade(ta, td, a, d)
  a["mysql"].delete("innodb_buffer_pool_size")
  a["mysql"].delete("max_connections")
  a["mysql"].delete("tmp_table_size")
  a["mysql"].delete("max_heap_table_size")
  return a, d
end
