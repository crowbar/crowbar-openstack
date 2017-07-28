def upgrade(ta, td, a, d)
  a["volume_defaults"]["netapp"]["storage_family"] = "ontap_cluster"
  return a, d
end

def downgrade(ta, td, a, d)
  a["volume_defaults"]["netapp"]["storage_family"] = "ontap_7mode"
  return a, d
end
