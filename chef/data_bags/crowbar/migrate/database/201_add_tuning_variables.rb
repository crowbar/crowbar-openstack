def upgrade(ta, td, a, d)
  unless a["mysql"].key? "innodb_buffer_pool_size"
    a["mysql"]["innodb_buffer_pool_size"] = ta["mysql"]["innodb_buffer_pool_size"]
  end

  unless a["mysql"].key? "max_connections"
    a["mysql"]["max_connections"] = ta["mysql"]["max_connections"]
  end

  unless a["mysql"].key? "tmp_table_size"
    a["mysql"]["tmp_table_size"] = ta["mysql"]["tmp_table_size"]
  end

  unless a["mysql"].key? "max_heap_table_size"
    a["mysql"]["max_heap_table_size"] = ta["mysql"]["max_heap_table_size"]
  end

  return a, d
end

def downgrade(ta, td, a, d)
  a["mysql"].delete("innodb_buffer_pool_size") unless ta["mysql"].key? "innodb_buffer_pool_size"
  a["mysql"].delete("max_connections") unless ta["mysql"].key? "max_connections"
  a["mysql"].delete("tmp_table_size") unless ta["mysql"].key? "tmp_table_size"
  a["mysql"].delete("max_heap_table_size") unless ta["mysql"].key? "max_heap_table_size"
  return a, d
end
