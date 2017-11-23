def upgrade(ta, td, a, d)
  a["use_l3_ha"] = ta["use_l3_ha"] unless a.key? "use_l3_ha"
  a["l3_ha_password"] = ta["l3_ha_password"] unless a.key? "l3_ha_password"
  return a, d
end

def downgrade(ta, td, a, d)
  a.delete("use_l3_ha") unless ta.key? "use_l3_ha"
  a.delete("l3_ha_password") unless ta.key? "l3_ha_password"
  return a, d
end
