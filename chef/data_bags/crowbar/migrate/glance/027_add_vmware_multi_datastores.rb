def upgrade(ta, td, a, d)
  if a["vsphere"]["datacenter_path"].empty? || a["vsphere"]["datastore"].empty?
    a["vsphere"]["datastores"] = ta["vsphere"]["datastores"]
  else
    a["vsphere"]["datastores"] = ["#{a["vsphere"]["datacenter_path"]}:#{a["vsphere"]["datastore"]}"]
  end
  a["vsphere"].delete("datastore")
  a["vsphere"].delete("datacenter_path")
  return a, d
end

def downgrade(ta, td, a, d)
  a["vsphere"]["datastore"] = ta["vsphere"]["datastore"]
  a["vsphere"]["datacenter_path"] = ta["vsphere"]["datacenter_path"]
  if a["vsphere"]["datastores"][0]
    datastore = a["vsphere"]["datastores"][0].split(":")
    if datastore.length >= 2
      a["vsphere"]["datacenter_path"] = datastore[0]
      a["vsphere"]["datastore"] = datastore[1]
    else
      a["vsphere"]["datastore"] = datastore[0]
    end
  end
  a["vsphere"].delete("datastores")
  return a, d
end
