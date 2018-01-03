def upgrade(ta, td, a, d)
  if a.key? "apic" and Hash === a["apic"]["opflex"]
    a["apic"]["opflex"]["nodes"] = a["apic"]["apic_switches"].map { \
      |_, value| value["switch_ports"].keys }.flatten.uniq
    a["apic"]["opflex"] = [ ta["apic"]["opflex"].first.merge(a["apic"]["opflex"]) ]
  end
  return a, d
end

def downgrade(ta, td, a, d)
  if a.key? "apic" and Array === ta["apic"]["opflex"]
    a["apic"]["opflex"] = a["apic"]["opflex"].first
    a["apic"]["opflex"].delete("pod")
    a["apic"]["opflex"].delete("nodes")
  end
  return a, d
end
