def upgrade(ta, td, a, d)
  a["container_sync"] = ta["container_sync"]

  # We use a class variable to set the same password in the proposal and in the
  # role, though
  unless defined?(@@swift_container_sync_key)
    service = ServiceObject.new "fake-logger"
    @@swift_container_sync_key = service.random_password
    @@swift_container_sync_key2 = service.random_password
  end
  a["container_sync"]["key"] = @@swift_container_sync_key
  a["container_sync"]["key2"] = @@swift_container_sync_key2

  return a, d
end

def downgrade(ta, td, a, d)
  a.delete("container_sync")
  return a, d
end
