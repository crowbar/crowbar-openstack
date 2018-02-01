def upgrade(tattr, tdep, attr, dep)
  unless attr["apic"].key?("apic_vmms")
    attr["apic"]["apic_vmms"] = tattr["apic"]["apic_vmms"]
  end

  return attr, dep
end

def downgrade(tattr, tdep, attr, dep)
  unless tattr["apic"].key?("apic_vmms")
    attr["apic"].delete("apic_vmms") if attr.key?("apic_vmms")
  end

  return attr, dep
end
