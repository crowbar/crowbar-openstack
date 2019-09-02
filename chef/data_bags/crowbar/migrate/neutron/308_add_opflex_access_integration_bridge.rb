def upgrade(tattr, tdep, attr, dep)
  unless attr["apic"]["opflex"].key?("integration_bridge")
    attr["apic"]["opflex"]["integration_bridge"] = tattr["apic"]["opflex"]["integration_bridge"]
  end
  unless attr["apic"]["opflex"].key?("access_bridge")
    attr["apic"]["opflex"]["access_bridge"] = tattr["apic"]["opflex"]["access_bridge"]
  end

  return attr, dep
end

def downgrade(tattr, tdep, attr, dep)
  unless tattr["apic"]["opflex"].key?("integration_bridge")
    attr["apic"]["opflex"].delete("integration_bridge") if attr.key?("integration_bridge")
  end
  unless tattr["apic"]["opflex"].key?("access_bridge")
    attr["apic"]["opflex"].delete("access_bridge") if attr.key?("access_bridge")
  end

  return attr, dep
end
