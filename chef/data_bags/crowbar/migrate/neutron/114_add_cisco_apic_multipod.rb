def upgrade(ta, td, a, d)
  if a.key?("apic") && a["apic"]["opflex"].is_a?(Hash)
    nodes = a["apic"]["apic_switches"]
            .map { |_, value| value["switch_ports"].keys }
            .flatten
            .uniq
    a["apic"]["opflex"]["nodes"] = nodes
    opflex = [ta["apic"]["opflex"].first.merge(a["apic"]["opflex"])]
    a["apic"]["opflex"] = opflex
  end
  return a, d
end

def downgrade(ta, td, a, d)
  if a.key?("apic") && ta["apic"]["opflex"].is_a?(Array)
    a["apic"]["opflex"] = a["apic"]["opflex"].first
    a["apic"]["opflex"].delete("pod")
    a["apic"]["opflex"].delete("nodes")
  end
  return a, d
end
