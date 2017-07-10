def upgrade(ta, td, a, d)
  a["apic"] = ta["apic"] unless a.key? "apic"
  return a, d
end

def downgrade(ta, td, a, d)
  a.delete("apic") unless ta.key? "apic"
  return a, d
end
