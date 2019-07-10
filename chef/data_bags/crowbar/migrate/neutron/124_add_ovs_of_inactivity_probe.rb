def upgrade(tattr, tdep, attr, dep)
  unless attr["ovs"].key?("of_inactivity_probe")
    attr["ovs"]["of_inactivity_probe"] = tattr["ovs"]["of_inactivity_probe"]
  end

  return attr, dep
end

def downgrade(tattr, tdep, attr, dep)
  unless tattr["ovs"].key?("of_inactivity_probe")
    attr["ovs"].delete("of_inactivity_probe") if attr.key?("ovs")
  end

  return attr, dep
end
