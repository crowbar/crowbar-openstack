def upgrade(template_attrs, template_deployment, attrs, deployment)
  attrs.delete("cpu_interval") unless template_attrs.key?("cpu_interval")
  attrs.delete("disk_interval") unless template_attrs.key?("disk_interval")
  attrs.delete("meters_interval") unless template_attrs.key?("meters_interval")
  attrs["compute_interval"] = template_attrs["compute_interval"] unless attrs.key?("compute_interval")
  attrs["image_interval"] = template_attrs["image_interval"] unless attrs.key?("image_interval")
  attrs["volume_interval"] = template_attrs["volume_interval"] unless attrs.key?("volume_interval")
  attrs["swift_interval"] = template_attrs["swift_interval"] unless attrs.key?("swift_interval")
  return attrs, deployment
end

def downgrade(template_attrs, template_deployment, attrs, deployment)
  attrs["cpu_interval"] = template_attrs["cpu_interval"] unless attrs.key?("cpu_interval")
  attrs["disk_interval"] = template_attrs["disk_interval"] unless attrs.key?("disk_interval")
  attrs["meters_interval"] = template_attrs["meters_interval"] unless attrs.key?("meters_interval")
  attrs.delete("compute_interval") unless template_attrs.key?("compute_interval")
  attrs.delete("image_interval") unless template_attrs.key?("image_interval")
  attrs.delete("volume_interval") unless template_attrs.key?("volume_interval")
  attrs.delete("swift_interval") unless template_attrs.key?("swift_interval")
  return attrs, deployment
end
