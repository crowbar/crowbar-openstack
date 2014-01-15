def upgrade ta, td, a, d
  case a["volume"]["netapp"]["netapp_driver"]
  when "cinder.volume.drivers.netapp.iscsi.NetAppDirect7modeISCSIDriver"
    a["volume"]["netapp"]["storage_protocol"] = "iscsi"
    a["volume"]["netapp"]["storage_family"] = "ontap_7mode"
  when "cinder.volume.drivers.netapp.nfs.NetAppDirect7modeNfsDriver"
    a["volume"]["netapp"]["storage_protocol"] = "nfs"
    a["volume"]["netapp"]["storage_family"] = "ontap_7mode"
  when "cinder.volume.drivers.netapp.iscsi.NetAppDirectCmodeISCSIDriver"
    a["volume"]["netapp"]["storage_protocol"] = "iscsi"
    a["volume"]["netapp"]["storage_family"] = "ontap_cluster"
  when "cinder.volume.drivers.netapp.nfs.NetAppDirectCmodeNfsDriver"
    a["volume"]["netapp"]["storage_protocol"] = "nfs"
    a["volume"]["netapp"]["storage_family"] = "ontap_cluster"
  else
    a["volume"]["netapp"]["storage_protocol"] = ta["volume"]["netapp"]["storage_protocol"]
    a["volume"]["netapp"]["storage_family"] = ta["volume"]["netapp"]["storage_family"]
  end
  a["volume"]["netapp"]["vserver"] = ta["volume"]["netapp"]["vserver"]
  a["volume"]["netapp"].delete("netapp_driver")
  a["volume"]["netapp"].delete("netapp_wsdl_url")
  a["volume"]["netapp"].delete("netapp_storage_service")
  a["volume"]["netapp"].delete("netapp_storage_service_prefix")
  return a, d
end

def downgrade ta, td, a, d
  # ideally we'd convert it backwards as well..
  a["volume"]["netapp"]["netapp_driver"] = ta["volume"]["netapp"]["netapp_driver"]
  a["volume"]["netapp"]["netapp_wsdl_url"] = ta["volume"]["netapp"]["netapp_wsdl_url"]
  a["volume"]["netapp"]["netapp_storage_service"] = ta["volume"]["netapp"]["netapp_storage_service"]
  a["volume"]["netapp"]["netapp_storage_service_prefix"] = ta["volume"]["netapp"]["netapp_storage_service_prefix"]
  a["volume"]["netapp"].delete('storage_family')
  a["volume"]["netapp"].delete('storage_protocol')
  a["volume"]["netapp"].delete('vserver')
  return a, d
end
