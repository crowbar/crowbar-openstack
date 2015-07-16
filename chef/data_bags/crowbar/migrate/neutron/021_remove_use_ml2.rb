def upgrade ta, td, a, d
  a.delete("use_ml2")
  return a, d
end

def downgrade ta, td, a, d
  unless a.include?("use_ml2")
    if a["networking_plugin"] == "vmware"
      a["use_ml2"] = false
    else
      a["use_ml2"] = true
    end
  end
  return a, d
end
