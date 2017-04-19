def upgrade(ta, td, a, d)
  a["apic"] = ta["apic"]
  return a, d
end

def downgrade(ta, td, a, d)
  a.delete("apic")
  return a, d
end
