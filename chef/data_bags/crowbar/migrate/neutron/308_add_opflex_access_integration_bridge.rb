def upgrade(tattr, tdep, att, dep)
  att["apic"]["opflex"].each_with_index do |opflex, i|
    unless opflex.key?("integration_bridge")
      att["apic"]["opflex"][i]["integration_bridge"] =
        tattr["apic"]["opflex"][0]["integration_bridge"]
    end
    unless opflex.key?("access_bridge")
      att["apic"]["opflex"][i]["access_bridge"] =
        tattr["apic"]["opflex"][0]["access_bridge"]
    end
  end
  return att, dep
end

def downgrade(tattr, tdep, att, dep)
  att["apic"]["opflex"].each_with_index do |opflex, i|
    unless tattr["apic"]["opflex"][0].key?("integration_bridge")
      att["apic"]["opflex"][i].delete("integration_bridge") if opflex.key?("integration_bridge")
    end
    unless tattr["apic"]["opflex"][0].key?("access_bridge")
      att["apic"]["opflex"][i].delete("access_bridge") if opflex.key?("access_bridge")
    end
  end

  return att, dep
end
