def upgrade(template_attrs, template_deployment, attrs, deployment)
  attrs["elasticsearch"]["tunables"].delete("max_open_files_soft_limit")
  attrs["elasticsearch"]["tunables"].delete("memory_lock")
  return attrs, deployment
end

def downgrade(template_attrs, template_deployment, attrs, deployment)
  attrs["elasticsearch"]["tunables"]["max_open_files_soft_limit"] =
    template_attrs["elasticsearch"]["tunables"]["max_open_files_soft_limit"]
  attrs["elasticsearch"]["tunables"]["memory_lock"] =
    template_attrs["elasticsearch"]["tunables"]["memory_lock"]
  return attrs, deployment
end
