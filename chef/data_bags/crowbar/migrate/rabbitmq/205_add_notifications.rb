def upgrade(ta, td, a, d)
  unless a["client"].key?("enable_notifications")
    # keep it always enabled on upgrade for compat
    a["client"]["enable_notifications"] = true
  end
  return a, d
end

def downgrade(ta, td, a, d)
  a["client"].delete("enable_notifications") unless ta["client"].key?("enable_notifications")
  return a, d
end
