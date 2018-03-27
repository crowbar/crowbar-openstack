def upgrade(ta, td, a, d)
  a["apic"]["ext_net"] = ta["apic"]["ext_net"] unless a["apic"].key? "ext_net"
  return a, d
end

def downgrade(ta, td, a, d)
  a["apic"].delete("ext_net") unless ta["apic"].key? "ext_net"
  return a, d
end
