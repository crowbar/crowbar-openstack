def upgrade(template_attrs, template_deployment, attrs, deployment)
  attrs["vcenter"]["vnc_keymap"] = attrs["vnc_keymap"]
  attrs.delete("vnc_keymap")
  return attrs, deployment
end

def downgrade(template_attrs, template_deployment, attrs, deployment)
  attrs["vcenter"].delete("vnc_keymap")
  attrs["vnc_keymap"] = template_attrs["vnc_keymap"]
  return attrs, deployment
end
