def upgrade(ta, td, a, d)
  unless a.key? "l3_ha"
    a["l3_ha"] = ta["l3_ha"]

    unless defined?(@@neutron_l3_ha_vrrp_password)
      service = ServiceObject.new "fake-logger"
      @@neutron_l3_ha_vrrp_password = service.random_password
    end

    a["l3_ha"]["vrrp_password"] = @@neutron_l3_ha_vrrp_password
  end

  return a, d
end

def downgrade(ta, td, a, d)
  unless ta.key?("l3_ha")
    a.delete("l3_ha")
  end

  return a, d
end
