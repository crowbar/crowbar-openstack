def upgrade(ta, td, a, d)
  unless a["mysql"]["innodb_flush_log_at_trx_commit"]
    a["mysql"]["innodb_flush_log_at_trx_commit"] = ta["mysql"]["innodb_flush_log_at_trx_commit"]
  end
  unless a["mysql"]["innodb_buffer_pool_instances"]
    a["mysql"]["innodb_buffer_pool_instances"] = ta["mysql"]["innodb_buffer_pool_instances"]
  end
  unless a["mysql"]["wsrep_slave_threads"]
    a["mysql"]["wsrep_slave_threads"] = ta["mysql"]["wsrep_slave_threads"]
  end
  return a, d
end

def downgrade(ta, td, a, d)
  unless ta["mysql"].key?("innodb_flush_log_at_trx_commit")
    a["mysql"].delete("innodb_flush_log_at_trx_commit")
  end
  unless ta["mysql"].key?("innodb_buffer_pool_instances")
    a["mysql"].delete("innodb_buffer_pool_instances")
  end
  a["mysql"].delete("wsrep_slave_threads") unless ta["mysql"].key?("wsrep_slave_threads")
  return a, d
end
