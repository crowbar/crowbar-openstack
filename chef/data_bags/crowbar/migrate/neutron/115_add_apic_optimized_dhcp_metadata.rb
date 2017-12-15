def upgrade(ta, td, a, d)
  a["apic"]["optimized_metadata"] = ta["apic"]["optimized_metadata"] \
    unless a["apic"].key? "optimized_metadata"
  a["apic"]["optimized_dhcp"] = ta["apic"]["optimized_dhcp"] unless a["apic"].key? "optimized_dhcp"
  return a, d
end

def downgrade(ta, td, a, d)
  a["apic"].delete("optimized_metadata") unless ta["apic"].key? "optimized_metadata"
  a["apic"].delete("optimized_dhcp") unless ta["apic"].key? "optimized_dhcp"
  return a, d
end
