def upgrade(template_attrs, template_deployment, attrs, deployment)
  attrs["agent"]["monitor_ovs"] = template_attrs["agent"]["monitor_ovs"] unless
    attrs["agent"].key?("monitor_ovs")

  attrs["agent"]["plugins"]["ovs"] = template_attrs["agent"]["plugins"]["ovs"] unless
    attrs["agent"]["plugins"].key?("ovs")

  return attrs, deployment
end

def downgrade(template_attrs, template_deployment, attrs, deployment)
  attrs["agent"].delete("monitor_ovs") unless
      template_attrs["agent"].key?("monitor_ovs")

  attrs["agent"]["plugins"].delete("ovs") unless
      template_attrs["agent"]["plugins"].key?("ovs")

  return attrs, deployment
end
