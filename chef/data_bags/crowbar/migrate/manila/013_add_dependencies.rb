def upgrade(ta, td, a, d)
  unless a.key? "nova_instance"
    a["nova_instance"] = ta["nova_instance"]
  end
  unless a.key? "cinder_instance"
    a["cinder_instance"] = ta["cinder_instance"]
  end
  unless a.key? "glance_instance"
    a["glance_instance"] = ta["glance_instance"]
  end
  unless a.key? "neutron_instance"
    a["neutron_instance"] = ta["neutron_instance"]
  end
  return a, d
end

def downgrade(ta, td, a, d)
  unless ta.key? "nova_instance"
    a.delete("nova_instance")
  end
  unless ta.key? "cinder_instance"
    a.delete("cinder_instance")
  end
  unless ta.key? "glance_instance"
    a.delete("glance_instance")
  end
  unless ta.key? "neutron_instance"
    a.delete("neutron_instance")
  end
  return a, d
end
