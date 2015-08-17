def upgrade ta, td, a, d
  unless a.include?("allow_overlapping_ips")
    a["allow_overlapping_ips"] = ta["allow_overlapping_ips"]
  end
  return a, d
end

def downgrade ta, td, a, d
  a.delete("allow_overlapping_ips")
  return a, d
end
