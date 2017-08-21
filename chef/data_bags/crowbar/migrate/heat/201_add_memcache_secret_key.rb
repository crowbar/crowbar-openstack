def upgrade(ta, td, a, d)
  if a["memcache_secret_key"].nil? || a["memcache_secret_key"].empty?
    service = ServiceObject.new "fake-logger"
    a["memcache_secret_key"] = service.random_password
  end
  return a, d
end

def downgrade(ta, td, a, d)
  a.delete("memcache_secret_key")
  return a, d
end
