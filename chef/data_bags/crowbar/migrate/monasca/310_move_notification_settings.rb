def upgrade(template_attrs, template_deployment, attrs, deployment)
  attrs["notification"] = template_attrs["notification"]
  attrs["notification"]["email_enabled"] = attrs["master"]["notification_enable_email"]
  attrs["notification"]["email_smtp_host"] = attrs["master"]["smtp_host"]
  attrs["notification"]["email_smtp_port"] = attrs["master"]["smtp_port"]
  attrs["notification"]["email_smtp_user"] = attrs["master"]["smtp_user"]
  attrs["notification"]["email_smtp_password"] = attrs["master"]["smtp_password"]
  attrs["notification"]["email_smtp_from_address"] = attrs["master"]["smtp_from_address"]
  ["notification_enable_email", "smtp_host", "smtp_port", "smtp_user",
   "smtp_password", "smtp_from_address"].each do |a|
    attrs["master"].delete(a)
  end
  return attrs, deployment
end

def downgrade(template_attrs, template_deployment, attrs, deployment)
  attrs["master"]["notification_enable_email"] = attrs["notification"]["email_enabled"]
  attrs["master"]["smtp_host"] = attrs["notification"]["email_smtp_host"]
  attrs["master"]["smtp_port"] = attrs["notification"]["email_smtp_port"]
  attrs["master"]["smtp_user"] = attrs["notification"]["email_smtp_user"]
  attrs["master"]["smtp_password"] = attrs["notification"]["email_smtp_password"]
  attrs["master"]["smtp_from_address"] = attrs["notification"]["email_smtp_from_address"]
  attrs.delete("notification")
  return attrs, deployment
end
